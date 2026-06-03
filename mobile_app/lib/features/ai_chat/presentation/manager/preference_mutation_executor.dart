import 'package:perfume_app/features/ai_chat/data/models/preference_patch.dart';
import 'package:perfume_app/features/ai_chat/data/models/session_preferences.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/preference_mutation_history.dart';

enum PreferenceMutationOperationType {
  setScalar,
  clearScalar,
  replaceList,
  appendList,
  removeFromList,
  undo,
}

class PreferenceMutationOperation {
  final PreferenceMutationOperationType type;
  final PreferenceScalar? scalar;
  final Object? scalarValue;
  final PreferenceListField? listField;
  final List<String> listValues;

  const PreferenceMutationOperation._({
    required this.type,
    this.scalar,
    this.scalarValue,
    this.listField,
    this.listValues = const <String>[],
  });

  const PreferenceMutationOperation.setScalar(
    PreferenceScalar scalar,
    Object? value,
  ) : this._(
        type: PreferenceMutationOperationType.setScalar,
        scalar: scalar,
        scalarValue: value,
      );

  const PreferenceMutationOperation.clearScalar(PreferenceScalar scalar)
    : this._(type: PreferenceMutationOperationType.clearScalar, scalar: scalar);

  const PreferenceMutationOperation.replaceList(
    PreferenceListField field,
    Iterable<String> values,
  ) : this._(
        type: PreferenceMutationOperationType.replaceList,
        listField: field,
        listValues: values is List<String> ? values : const <String>[],
      );

  factory PreferenceMutationOperation.replaceListValues(
    PreferenceListField field,
    Iterable<String> values,
  ) {
    return PreferenceMutationOperation._(
      type: PreferenceMutationOperationType.replaceList,
      listField: field,
      listValues: values.toList(growable: false),
    );
  }

  factory PreferenceMutationOperation.appendList(
    PreferenceListField field,
    Iterable<String> values,
  ) {
    return PreferenceMutationOperation._(
      type: PreferenceMutationOperationType.appendList,
      listField: field,
      listValues: values.toList(growable: false),
    );
  }

  factory PreferenceMutationOperation.removeFromList(
    PreferenceListField field,
    Iterable<String> values,
  ) {
    return PreferenceMutationOperation._(
      type: PreferenceMutationOperationType.removeFromList,
      listField: field,
      listValues: values.toList(growable: false),
    );
  }

  const PreferenceMutationOperation.undo()
    : this._(type: PreferenceMutationOperationType.undo);
}

class PreferenceMutationRequest {
  final List<PreferenceMutationOperation> operations;
  final String source;

  const PreferenceMutationRequest({
    required this.operations,
    this.source = 'structured_mutation',
  });
}

class PreferenceMutationExecutionResult {
  final SessionPreferences preferences;
  final PreferenceMutationHistory history;
  final bool didMutate;
  final bool didUndo;

  const PreferenceMutationExecutionResult({
    required this.preferences,
    required this.history,
    required this.didMutate,
    required this.didUndo,
  });
}

class PreferenceMutationExecutor {
  const PreferenceMutationExecutor();

  PreferenceMutationExecutionResult execute({
    required SessionPreferences current,
    required PreferenceMutationRequest request,
    PreferenceMutationHistory history = const PreferenceMutationHistory(),
  }) {
    if (request.operations.length == 1 &&
        request.operations.single.type ==
            PreferenceMutationOperationType.undo) {
      final undo = history.undo(current);
      return PreferenceMutationExecutionResult(
        preferences: undo.preferences,
        history: undo.history,
        didMutate: undo.didUndo,
        didUndo: undo.didUndo,
      );
    }

    final patch = PreferencePatch();
    for (final operation in request.operations) {
      _applyOperation(patch, operation);
    }
    return applyPatch(
      current: current,
      patch: patch,
      history: history,
      source: request.source,
    );
  }

  PreferenceMutationExecutionResult applyPatch({
    required SessionPreferences current,
    required PreferencePatch patch,
    PreferenceMutationHistory history = const PreferenceMutationHistory(),
    String source = 'preference_patch',
  }) {
    if (patch.isEmpty) {
      return PreferenceMutationExecutionResult(
        preferences: current,
        history: history,
        didMutate: false,
        didUndo: false,
      );
    }
    final updated = patch.applyTo(current);
    return PreferenceMutationExecutionResult(
      preferences: updated,
      history: history.push(before: current, after: updated, source: source),
      didMutate: updated != current,
      didUndo: false,
    );
  }

  void _applyOperation(
    PreferencePatch patch,
    PreferenceMutationOperation operation,
  ) {
    switch (operation.type) {
      case PreferenceMutationOperationType.setScalar:
        final scalar = operation.scalar;
        if (scalar != null) patch.setScalar(scalar, operation.scalarValue);
        break;
      case PreferenceMutationOperationType.clearScalar:
        final scalar = operation.scalar;
        if (scalar != null) patch.clearScalar(scalar);
        break;
      case PreferenceMutationOperationType.replaceList:
        final field = operation.listField;
        if (field != null) patch.replaceList(field, operation.listValues);
        break;
      case PreferenceMutationOperationType.appendList:
        final field = operation.listField;
        if (field != null) patch.appendList(field, operation.listValues);
        break;
      case PreferenceMutationOperationType.removeFromList:
        final field = operation.listField;
        if (field != null) patch.removeFromList(field, operation.listValues);
        break;
      case PreferenceMutationOperationType.undo:
        break;
    }
  }
}
