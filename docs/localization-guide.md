# Localization Standard Guide

> Documentation freshness note, 2026-05-13: reviewed during the latest documentation refresh. This remains the localization convention reference; current project readiness lives in `docs/current-project-status.md`.

This document defines the naming and extraction rules for the Perfume App to ensure a consistent and maintainable translation system.

## 1. Naming Conventions (Keys)
All keys MUST follow the **`camelCase`** format. No underscores or hyphens allowed.

### Prefixes for Organization
To keep keys grouped logically, use the following prefixes:
- `label...`: Static text for labels, titles, and headers.
- `btn...`: Interactive text for buttons and clickable elements.
- `msg...`: Complete sentences, notifications, or status messages.
- `hint...`: Placeholder text for input fields.
- `err...`: Error or validation messages.

**Example**: `btnLogin`, `labelEmailAddress`, `msgOrderSuccessful`.

---

## 2. Placeholders Syntax
For dynamic content (names, numbers, prices), use curly braces `{}`.

### Placeholder Rules
1. **Naming**: Use descriptive camelCase names for placeholders (e.g., `{userName}`, `{numItems}`).
2. **Metadata**: Every key with a placeholder **MUST** have a corresponding `@key` metadata entry.
3. **Types**: Specify the `type` in metadata to ensure type-safety in Dart.

**Supported Types**:
- `String`: Default for most text.
- `int`: For counts, quantities, or days.
- `num` or `double`: For currency and weights.

---

## 3. Reference Examples

### Static Text
```json
"btnContinue": "Continue"
```

### Dynamic Text with Description
```json
"msgWelcomeName": "Welcome, {name}!",
"@msgWelcomeName": {
  "description": "Welcome message shown on the home screen",
  "placeholders": {
    "name": {
      "type": "String",
      "example": "Ahmed"
    }
  }
}
```

### Pluralization (Advanced)
*Note: Use sparingly where grammatically necessary.*
```json
"msgItemCount": "{count, plural, =0{No items} =1{1 item} other{{count} items}}",
"@msgItemCount": {
  "description": "Counter for items in the cart",
  "placeholders": {
    "count": {
      "type": "num",
      "format": "compact"
    }
  }
}
```

---

## 4. Best Practices
1. **User-Facing Only**: Do not localize logger messages or technical error codes.
2. **Context Matters**: Use the `description` field in metadata to explain where the string appears.
3. **Avoid Concatenation**: Never build sentences by concatenating keys in code. Use placeholders instead.
   - **WRONG**: `l10n.hello + " " + userName`
   - **RIGHT**: `l10n.msgHelloUser(userName)`
