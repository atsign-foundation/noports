import 'package:at_client_flutter/at_client_flutter.dart' show SppData;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:npt_flutter/features/authorisation/controller/authorisation_hub_controller.dart';
import 'package:npt_flutter/features/authorisation/util/pretty_duration.dart';
import 'package:npt_flutter/features/authorisation/widgets/spp_expiration.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

const int kSppLength = 6;

class SppWidget extends StatefulWidget {
  const SppWidget({required this.controller, super.key});

  final AuthorisationHubController controller;

  @override
  State<SppWidget> createState() => _SppWidgetState();
}

class _SppWidgetState extends State<SppWidget> {
  static const double _fieldHeight = 50.0;
  static const double _fieldWidth = 44.0;
  static const double _fieldPadding = 24.0;
  static const List<Duration> _durationOptions = <Duration>[
    Duration(minutes: 2),
    Duration(minutes: 5),
    Duration(minutes: 10),
    Duration(minutes: 30),
    Duration(hours: 1),
  ];

  final TextEditingController _pinController = TextEditingController();

  Duration _selectedDuration = _durationOptions.first;
  bool _saveEnabled = false;
  String? _lastAppliedSpp;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final SppData? spp = widget.controller.spp;
    if (spp != null && spp.value != _lastAppliedSpp) {
      _lastAppliedSpp = spp.value;
      _pinController.text = spp.value;
      _saveEnabled = spp.value.length == kSppLength;
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AuthorisationHubController controller = widget.controller;
    final SppData? spp = controller.spp;
    final bool hasLiveSpp = spp != null && spp.expiry.isAfter(DateTime.now());

    return SizedBox(
      width: kSppLength * (_fieldWidth + _fieldPadding) + _fieldPadding * 2,
      child: Card(
        elevation: 0,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.all(_fieldPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (hasLiveSpp) ...<Widget>[
                SppExpiration(
                  expiryTime: spp.expiry,
                  onExpiry: () {
                    _pinController.clear();
                    _lastAppliedSpp = null;
                    if (mounted) {
                      setState(() {
                        _saveEnabled = false;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
              ],
              Row(
                children: <Widget>[
                  Tooltip(
                    message: 'Duration before the pin expires',
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          Icons.timer_outlined,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          'Duration:',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),
                  Expanded(
                    child: DropdownButton<Duration>(
                      underline: const SizedBox.shrink(),
                      isExpanded: true,
                      value: _selectedDuration,
                      onChanged: (Duration? value) {
                        if (value == null) return;
                        setState(() {
                          _selectedDuration = value;
                        });
                      },
                      items: _durationOptions
                          .map<DropdownMenuItem<Duration>>((Duration option) {
                            return DropdownMenuItem<Duration>(
                              value: option,
                              child: Text(prettyDuration(option)),
                            );
                          })
                          .toList(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              PinCodeTextField(
                appContext: context,
                controller: _pinController,
                autoDisposeControllers: false,
                length: kSppLength,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                textCapitalization: TextCapitalization.characters,
                cursorColor: Theme.of(context).colorScheme.primary,
                animationType: AnimationType.fade,
                enableActiveFill: true,
                inputFormatters: <TextInputFormatter>[
                  _UpperCaseTextFormatter(),
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                ],
                onChanged: (String value) {
                  setState(() {
                    _saveEnabled = value.length == kSppLength;
                  });
                },
                pinTheme: PinTheme(
                  shape: PinCodeFieldShape.box,
                  borderRadius: BorderRadius.circular(4),
                  fieldHeight: _fieldHeight,
                  fieldWidth: _fieldWidth,
                  activeColor: Colors.transparent,
                  inactiveColor: Colors.transparent,
                  selectedColor: Theme.of(context).colorScheme.primary,
                  activeFillColor: Theme.of(context).colorScheme.surface,
                  selectedFillColor: Theme.of(context).colorScheme.surface,
                  inactiveFillColor: Theme.of(context).colorScheme.surface,
                  borderWidth: 1,
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _saveEnabled && !controller.sppSaving
                    ? () async {
                        await controller.setSpp(
                          _pinController.text,
                          _selectedDuration,
                        );
                      }
                    : null,
                child: controller.sppSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              ),
              if (controller.sppSaveError != null)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    controller.sppSaveError!,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
