import 'package:flutter_test/flutter_test.dart';

import '../tool/validate_public_api_docs.dart';

void main() {
  test('checklist ignores later sections and prose about public members', () {
    expect(
      checklistSymbols('''
## Before
- `Unrelated`
## Symbol Coverage Checklist
The public wallet exposes `reinit`.
- `UtexoWallet`, `PasswordRlnSigner`
- `StaleExport`
### Checklist notes
`notAnExport`
## Mainnet Support
- `reinit`
- `init`
'''),
      {'UtexoWallet', 'PasswordRlnSigner', 'StaleExport'},
    );
    expect(checklistSymbols('## Other\n- `NotChecklist`\n'), isEmpty);
  });
}
