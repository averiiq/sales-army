/// Reusable form validators. Each function returns `null` when the input is
/// acceptable and an error message string when it is not — matching the
/// contract Flutter's `FormField.validator` expects. Compose them with
/// [combine] when a field has multiple rules.
///
/// Usage:
/// ```dart
/// TextFormField(
///   validator: FormValidators.combine([
///     FormValidators.required('Shop name'),
///     FormValidators.maxLength(80),
///   ]),
/// )
/// ```
class FormValidators {
  FormValidators._();

  // ---------------------------------------------------------------------------
  // Composition
  // ---------------------------------------------------------------------------

  /// Runs each validator in order and returns the first error encountered.
  /// A null result from every validator means the field passes.
  static String? Function(String?) combine(
      List<String? Function(String?)> validators) {
    return (value) {
      for (final v in validators) {
        final err = v(value);
        if (err != null) return err;
      }
      return null;
    };
  }

  // ---------------------------------------------------------------------------
  // Base rules
  // ---------------------------------------------------------------------------

  /// Field must be non-null and non-blank after trimming.
  static String? Function(String?) required(String fieldName) =>
      (value) => (value == null || value.trim().isEmpty) ? '$fieldName is required' : null;

  /// At least [min] characters after trimming.
  static String? Function(String?) minLength(int min, {String? fieldName}) =>
      (value) {
        final text = (value ?? '').trim();
        if (text.length < min) {
          return '${fieldName ?? "Must be"} at least $min character${min == 1 ? "" : "s"}';
        }
        return null;
      };

  /// Up to [max] characters after trimming.
  static String? Function(String?) maxLength(int max, {String? fieldName}) =>
      (value) {
        final text = (value ?? '').trim();
        if (text.length > max) {
          return '${fieldName ?? "Must be"} no more than $max characters';
        }
        return null;
      };

  // ---------------------------------------------------------------------------
  // Numeric rules
  // ---------------------------------------------------------------------------

  /// Parses as a double > 0 (e.g. payment amount, selling price).
  static String? Function(String?) positiveAmount({String fieldName = 'Amount'}) =>
      (value) {
        final text = (value ?? '').trim();
        final parsed = double.tryParse(text);
        if (parsed == null) return '$fieldName must be a number';
        if (parsed <= 0) return '$fieldName must be greater than zero';
        return null;
      };

  /// Parses as a double >= 0 (zero allowed — e.g. GST rate).
  static String? Function(String?) nonNegativeAmount({String fieldName = 'Value'}) =>
      (value) {
        final text = (value ?? '').trim();
        final parsed = double.tryParse(text);
        if (parsed == null) return '$fieldName must be a number';
        if (parsed < 0) return '$fieldName cannot be negative';
        return null;
      };

  /// Parses as an integer >= 1 (e.g. quantity, pack size).
  static String? Function(String?) positiveInt({String fieldName = 'Quantity'}) =>
      (value) {
        final text = (value ?? '').trim();
        final parsed = int.tryParse(text);
        if (parsed == null) return '$fieldName must be a whole number';
        if (parsed < 1) return '$fieldName must be at least 1';
        return null;
      };

  /// Parses as integer >= 0 (zero allowed — e.g. stock quantity, re-order threshold).
  static String? Function(String?) nonNegativeInt({String fieldName = 'Value'}) =>
      (value) {
        final text = (value ?? '').trim();
        final parsed = int.tryParse(text);
        if (parsed == null) return '$fieldName must be a whole number';
        if (parsed < 0) return '$fieldName cannot be negative';
        return null;
      };

  // ---------------------------------------------------------------------------
  // Business-identity rules (Indian context)
  // ---------------------------------------------------------------------------

  /// Email format — permissive enough to match real-world patterns like
  /// `name+tag@sub.domain.co.in`, strict enough to reject whitespace and
  /// missing `@`.
  static String? Function(String?) email({bool optional = false}) =>
      (value) {
        final text = (value ?? '').trim();
        if (text.isEmpty) return optional ? null : 'Email is required';
        final regex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
        if (!regex.hasMatch(text)) return 'Enter a valid email address';
        return null;
      };

  /// Indian mobile number: optional `+91 ` prefix or just 10 digits. Accepts
  /// spaces and dashes between digits.
  static String? Function(String?) indianPhone({bool optional = false}) =>
      (value) {
        final text = (value ?? '').trim();
        if (text.isEmpty) return optional ? null : 'Mobile is required';
        final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
        // Must be 10 digits (local) or 12 digits (with 91 country code).
        if (digits.length != 10 && digits.length != 12) {
          return 'Enter a 10-digit Indian mobile number';
        }
        if (digits.length == 10 && !RegExp(r'^[6-9]').hasMatch(digits)) {
          return 'Mobile must start with 6, 7, 8 or 9';
        }
        if (digits.length == 12 && !digits.startsWith('91')) {
          return 'Use +91 country code or just 10 digits';
        }
        return null;
      };

  /// Indian GSTIN: 15 chars — 2-digit state code, 10-char PAN, 1 entity code,
  /// 'Z' literal, 1 check char. Matches the canonical regex published by
  /// GSTN. GSTIN is often optional (B2C retailers don't need it).
  static String? Function(String?) gstin({bool optional = true}) =>
      (value) {
        final text = (value ?? '').trim().toUpperCase();
        if (text.isEmpty) return optional ? null : 'GSTIN is required';
        final regex = RegExp(r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$');
        if (!regex.hasMatch(text)) return 'Enter a valid 15-digit GSTIN';
        return null;
      };

  /// Indian PAN: 10 chars — 5 letters, 4 digits, 1 letter. Fourth character
  /// encodes the entity type (P=person, C=company, H=HUF, F=firm, …).
  static String? Function(String?) pan({bool optional = true}) =>
      (value) {
        final text = (value ?? '').trim().toUpperCase();
        if (text.isEmpty) return optional ? null : 'PAN is required';
        final regex = RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]{1}$');
        if (!regex.hasMatch(text)) return 'Enter a valid 10-character PAN';
        return null;
      };

  /// Indian 6-digit PIN code.
  static String? Function(String?) pinCode({bool optional = false}) =>
      (value) {
        final text = (value ?? '').trim();
        if (text.isEmpty) return optional ? null : 'PIN code is required';
        if (!RegExp(r'^[1-9][0-9]{5}$').hasMatch(text)) {
          return 'Enter a valid 6-digit PIN code';
        }
        return null;
      };

  /// UPI VPA: `user@handle` form. Non-empty required unless [optional] = true.
  static String? Function(String?) upiVpa({bool optional = true}) =>
      (value) {
        final text = (value ?? '').trim();
        if (text.isEmpty) return optional ? null : 'UPI ID is required';
        if (!RegExp(r'^[a-zA-Z0-9._\-]{3,}@[a-zA-Z]{3,}$').hasMatch(text)) {
          return 'Enter a valid UPI ID (e.g. name@okhdfcbank)';
        }
        return null;
      };

  /// Password strength: at least 6 chars.
  static String? Function(String?) password({int minChars = 6}) =>
      (value) {
        final text = value ?? '';
        if (text.isEmpty) return 'Password is required';
        if (text.length < minChars) {
          return 'Password must be at least $minChars characters';
        }
        return null;
      };
}
