import 'package:flutter/material.dart';

import '../../theme/admin_theme.dart';

/// Result of the suspension dialog.
/// [temporary] false => permanent suspension (until the owner activates).
/// [temporary] true  => suspended for exactly [durationMs].
class SuspendChoice {
  SuspendChoice.permanent()
      : temporary = false,
        durationMs = 0;

  SuspendChoice.temporary(this.durationMs)
      : temporary = true;

  final bool temporary;
  final int durationMs;
}

/// Suspension sheet: permanent or temporary with an hh:mm:ss picker
/// (hours : minutes : seconds), matching the trial-duration picker style.
class SuspendDialog extends StatefulWidget {
  SuspendDialog({super.key, required this.username});

  final String username;

  @override
  State<SuspendDialog> createState() => _SuspendDialogState();
}

class _SuspendDialogState extends State<SuspendDialog> {
  bool _temporary = false;
  int _hours = 1;
  int _minutes = 0;
  int _seconds = 0;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('إيقاف الحساب "${widget.username}"'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text('نوع الإيقاف:',
                style: TextStyle(color: AdminPalette.textDim, fontSize: 13)),
            SizedBox(height: 6),
            SegmentedButton<bool>(
              segments: <ButtonSegment<bool>>[
                ButtonSegment<bool>(
                  value: false,
                  label: Text('دائم'),
                  icon: Icon(Icons.block),
                ),
                ButtonSegment<bool>(
                  value: true,
                  label: Text('مؤقت'),
                  icon: Icon(Icons.hourglass_bottom),
                ),
              ],
              selected: <bool>{_temporary},
              onSelectionChanged: (Set<bool> s) =>
                  setState(() => _temporary = s.first),
            ),
            if (_temporary) ...<Widget>[
              SizedBox(height: 14),
              Text('مدة الإيقاف (ساعات : دقائق : ثواني):',
                  style: TextStyle(color: AdminPalette.textDim, fontSize: 13)),
              SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  _numField(_hours, 0, 1000000, (int v) => setState(() => _hours = v)),
                  _colon(),
                  _numField(_minutes, 0, 59, (int v) => setState(() => _minutes = v)),
                  _colon(),
                  _numField(_seconds, 0, 59, (int v) => setState(() => _seconds = v)),
                ],
              ),
            ],
            SizedBox(height: 10),
            Text(
              _temporary
                  ? 'سيُمنع الدخول طوال المدة ثم يُعاد تلقائياً.'
                  : 'سيُمنع الدخول نهائياً حتى تضغط "تفعيل".',
              style: TextStyle(
                  color: AdminPalette.textDim, fontSize: 12),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('إلغاء'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: AdminPalette.alarm),
          onPressed: () {
            final SuspendChoice choice = _temporary
                ? SuspendChoice.temporary(
                    _hours * 3600000 + _minutes * 60000 + _seconds * 1000)
                : SuspendChoice.permanent();
            Navigator.of(context).pop(choice);
          },
          child: Text('إيقاف'),
        ),
      ],
    );
  }

  Widget _colon() => Padding(
        padding: EdgeInsets.symmetric(horizontal: 6),
        child: Text(':',
            style: TextStyle(
                color: AdminPalette.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w900)),
      );

  Widget _numField(int value, int min, int max, ValueChanged<int> onChanged) {
    final TextEditingController c =
        TextEditingController(text: value.toString());
    return SizedBox(
      width: 72,
      child: TextField(
        controller: c,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 7,
        style: TextStyle(
            color: AdminPalette.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w800),
        decoration: InputDecoration(counterText: ''),
        onChanged: (String s) {
          final int? v = int.tryParse(s);
          if (v == null) return;
          onChanged(v.clamp(min, max));
        },
      ),
    );
  }
}