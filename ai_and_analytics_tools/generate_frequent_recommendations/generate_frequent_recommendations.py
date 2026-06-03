"""
Offline FP-Growth mining script for `frequent_recommendations`.

Usage examples:
  python tools/generate_frequent_recommendations.py --dry-run
  python tools/generate_frequent_recommendations.py --min-support 0.03 --upload

Requirements:
  pip install -r tools/requirements-frequent-recommendations.txt

Authentication:
  Configure Firebase Admin credentials in your environment before running.
"""

from __future__ import annotations

import argparse
import json
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

import firebase_admin
from firebase_admin import credentials, firestore
import pandas as pd
from mlxtend.frequent_patterns import association_rules, fpgrowth
from mlxtend.preprocessing import TransactionEncoder


VALID_STATUSES = {
    "pending",
    "order_processing",
    "out_for_delivery",
    "delivered",
}


@dataclass(frozen=True)
class MiningConfig:
    min_support: float
    min_confidence: float
    min_lift: float
    limit_per_product: int
    output_path: Path
    upload: bool
    service_account_path: Path | None


def parse_args() -> MiningConfig:
    parser = argparse.ArgumentParser(
        description="Generate frequent product recommendations using FP-Growth.",
    )
    parser.add_argument("--min-support", type=float, default=0.03)
    parser.add_argument("--min-confidence", type=float, default=0.50)
    parser.add_argument("--min-lift", type=float, default=1.10)
    parser.add_argument("--limit-per-product", type=int, default=3)
    parser.add_argument(
        "--output",
        type=Path,
        default=Path("tools/generated_frequent_recommendations.json"),
    )
    parser.add_argument(
        "--upload",
        action="store_true",
        help="Upload generated documents to Firestore.",
    )
    parser.add_argument(
        "--service-account",
        type=Path,
        default=None,
        help="Path to Firebase service account JSON file.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Generate output locally without uploading.",
    )
    args = parser.parse_args()

    return MiningConfig(
        min_support=args.min_support,
        min_confidence=args.min_confidence,
        min_lift=args.min_lift,
        limit_per_product=args.limit_per_product,
        output_path=args.output,
        upload=args.upload and not args.dry_run,
        service_account_path=args.service_account,
    )


def initialize_firestore_client(config: MiningConfig) -> firestore.Client:
    if firebase_admin._apps:
        return firestore.client()

    if config.service_account_path is not None:
        firebase_admin.initialize_app(
            credentials.Certificate(str(config.service_account_path)),
        )
    else:
        firebase_admin.initialize_app(credentials.ApplicationDefault())

    return firestore.client()


def fetch_transactions(db: firestore.Client) -> list[list[str]]:
    docs = db.collection("orders").stream()
    transactions: list[list[str]] = []

    for doc in docs:
      data = doc.to_dict() or {}
      status = str(data.get("status", "")).strip()
      if status not in VALID_STATUSES:
          continue

      items = data.get("items") or []
      unique_ids = sorted(
          {
              str(item.get("productId", "")).strip()
              for item in items
              if isinstance(item, dict)
          }
      )

      filtered_ids = [product_id for product_id in unique_ids if product_id]
      if len(filtered_ids) < 2:
          continue

      transactions.append(filtered_ids)

    return transactions


def mine_rules(
    transactions: list[list[str]],
    config: MiningConfig,
) -> pd.DataFrame:
    if not transactions:
        return pd.DataFrame()

    encoder = TransactionEncoder()
    encoded_array = encoder.fit(transactions).transform(transactions)
    basket = pd.DataFrame(encoded_array, columns=encoder.columns_)

    itemsets = fpgrowth(
        basket,
        min_support=config.min_support,
        use_colnames=True,
    )
    if itemsets.empty:
        return pd.DataFrame()

    rules = association_rules(
        itemsets,
        metric="confidence",
        min_threshold=config.min_confidence,
    )
    if rules.empty:
        return pd.DataFrame()

    filtered = rules[
        (rules["lift"] >= config.min_lift)
        & (rules["antecedents"].apply(len) == 1)
        & (rules["consequents"].apply(len) == 1)
    ].copy()
    if filtered.empty:
        return pd.DataFrame()

    filtered["trigger_product_id"] = filtered["antecedents"].apply(
        lambda values: next(iter(values))
    )
    filtered["recommended_product_id"] = filtered["consequents"].apply(
        lambda values: next(iter(values))
    )

    return filtered.sort_values(
        by=["confidence", "lift", "support"],
        ascending=[False, False, False],
    )


def build_documents(
    rules: pd.DataFrame,
    config: MiningConfig,
) -> dict[str, dict]:
    documents: dict[str, dict] = {}
    grouped: dict[str, list[dict]] = defaultdict(list)

    for _, row in rules.iterrows():
        trigger_id = row["trigger_product_id"]
        grouped[trigger_id].append(
            {
                "product_id": row["recommended_product_id"],
                "confidence": round(float(row["confidence"]), 4),
                "support": round(float(row["support"]), 4),
                "lift": round(float(row["lift"]), 4),
            }
        )

    for trigger_id, recommendations in grouped.items():
        documents[trigger_id] = {
            "trigger_product_id": trigger_id,
            "recommended_products": recommendations[: config.limit_per_product],
            "source": "fp_growth_v1",
        }

    return documents


def write_output(path: Path, documents: dict[str, dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as file:
        json.dump(documents, file, ensure_ascii=False, indent=2)


def upload_documents(db: firestore.Client, documents: dict[str, dict]) -> None:
    collection = db.collection("frequent_recommendations")
    existing_docs = {doc.id for doc in collection.stream()}
    new_doc_ids = set(documents.keys())

    batch = db.batch()
    operation_count = 0

    def commit_batch() -> None:
        nonlocal batch, operation_count
        if operation_count == 0:
            return
        batch.commit()
        batch = db.batch()
        operation_count = 0

    for trigger_id, payload in documents.items():
        batch.set(
            collection.document(trigger_id),
            {
                **payload,
                "updated_at": firestore.SERVER_TIMESTAMP,
            },
        )
        operation_count += 1
        if operation_count >= 400:
            commit_batch()

    for stale_doc_id in existing_docs - new_doc_ids:
        batch.delete(collection.document(stale_doc_id))
        operation_count += 1
        if operation_count >= 400:
            commit_batch()

    commit_batch()


def print_summary(
    transactions: Iterable[list[str]],
    rules: pd.DataFrame,
    documents: dict[str, dict],
    config: MiningConfig,
) -> None:
    transaction_count = len(list(transactions))
    print(f"Transactions used: {transaction_count}")
    print(f"Rules generated: {0 if rules.empty else len(rules)}")
    print(f"Trigger products generated: {len(documents)}")
    print(
        "Thresholds:"
        f" support>={config.min_support},"
        f" confidence>={config.min_confidence},"
        f" lift>={config.min_lift}"
    )


def main() -> None:
    config = parse_args()
    db = initialize_firestore_client(config)
    transactions = fetch_transactions(db)
    rules = mine_rules(transactions, config)
    documents = build_documents(rules, config)
    write_output(config.output_path, documents)
    print_summary(transactions, rules, documents, config)
    print(f"Local output written to: {config.output_path}")

    if config.upload:
        upload_documents(db, documents)
        print("Uploaded documents to `frequent_recommendations`.")
    else:
        print("Upload skipped. Use --upload when ready.")


if __name__ == "__main__":
    main()
