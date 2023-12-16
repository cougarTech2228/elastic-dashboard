import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/services/nt4.dart';
import 'package:elastic_dashboard/services/nt4_connection.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_text_input.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/nt4_widget.dart';

class ProfiledPIDControllerWidget extends NT4Widget {
  static const String widgetType = 'ProfiledPIDController';
  @override
  String type = widgetType;

  late String kpTopicName;
  late String kiTopicName;
  late String kdTopicName;
  late String goalTopicName;

  NT4Topic? kpTopic;
  NT4Topic? kiTopic;
  NT4Topic? kdTopic;
  NT4Topic? goalTopic;

  TextEditingController? kpTextController;
  TextEditingController? kiTextController;
  TextEditingController? kdTextController;
  TextEditingController? goalTextController;

  double kpLastValue = 0.0;
  double kiLastValue = 0.0;
  double kdLastValue = 0.0;
  double goalLastValue = 0.0;

  ProfiledPIDControllerWidget({
    super.key,
    required super.topic,
    kpTopic,
    kiTopic,
    kdTopic,
    setpointTopic,
    super.dataType,
    super.period,
  }) : super();

  ProfiledPIDControllerWidget.fromJson({super.key, required super.jsonData})
      : super.fromJson();

  @override
  void init() {
    super.init();

    kpTopicName = '$topic/p';
    kiTopicName = '$topic/i';
    kdTopicName = '$topic/d';
    goalTopicName = '$topic/goal';
  }

  @override
  void resetSubscription() {
    kpTopicName = '$topic/p';
    kiTopicName = '$topic/i';
    kdTopicName = '$topic/d';
    goalTopicName = '$topic/setpoint';

    kpTopic = null;
    kiTopic = null;
    kdTopic = null;
    goalTopic = null;

    super.resetSubscription();
  }

  @override
  List<Object> getCurrentData() {
    double kP =
        tryCast(nt4Connection.getLastAnnouncedValue(kpTopicName)) ?? 0.0;
    double kI =
        tryCast(nt4Connection.getLastAnnouncedValue(kiTopicName)) ?? 0.0;
    double kD =
        tryCast(nt4Connection.getLastAnnouncedValue(kdTopicName)) ?? 0.0;
    double goal =
        tryCast(nt4Connection.getLastAnnouncedValue(goalTopicName)) ?? 0.0;

    return [kP, kI, kD, goal];
  }

  @override
  Widget build(BuildContext context) {
    notifier = context.watch<NT4WidgetNotifier?>();

    return StreamBuilder(
        stream: multiTopicPeriodicStream,
        builder: (context, snapshot) {
          notifier = context.watch<NT4WidgetNotifier?>();

          double kP =
              tryCast(nt4Connection.getLastAnnouncedValue(kpTopicName)) ?? 0.0;
          double kI =
              tryCast(nt4Connection.getLastAnnouncedValue(kiTopicName)) ?? 0.0;
          double kD =
              tryCast(nt4Connection.getLastAnnouncedValue(kdTopicName)) ?? 0.0;
          double goal =
              tryCast(nt4Connection.getLastAnnouncedValue(goalTopicName)) ??
                  0.0;

          // Creates the text editing controllers if they are null
          kpTextController ??= TextEditingController(text: kP.toString());
          kiTextController ??= TextEditingController(text: kI.toString());
          kdTextController ??= TextEditingController(text: kD.toString());
          goalTextController ??= TextEditingController(text: goal.toString());

          // Updates the text of the text editing controller if the kp value has changed
          if (kP != kpLastValue) {
            kpTextController!.text = kP.toString();
          }
          kpLastValue = kP;

          // Updates the text of the text editing controller if the ki value has changed
          if (kI != kiLastValue) {
            kiTextController!.text = kI.toString();
          }
          kiLastValue = kI;

          // Updates the text of the text editing controller if the kd value has changed
          if (kD != kdLastValue) {
            kdTextController!.text = kD.toString();
          }
          kdLastValue = kD;

          // Updates the text of the text editing controller if the setpoint value has changed
          if (goal != goalLastValue) {
            goalTextController!.text = goal.toString();
          }
          goalLastValue = goal;

          TextStyle labelStyle =
              Theme.of(context).textTheme.bodyLarge!.copyWith(
                    fontWeight: FontWeight.bold,
                  );

          return Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // kP
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Spacer(),
                  Text('P', style: labelStyle),
                  const Spacer(),
                  Flexible(
                    flex: 5,
                    child: DialogTextInput(
                      textEditingController: kpTextController,
                      initialText: kpTextController!.text,
                      label: 'kP',
                      onSubmit: (value) {
                        bool publishTopic = kpTopic == null;

                        kpTopic ??= nt4Connection.getTopicFromName(kpTopicName);

                        double? data = double.tryParse(value);

                        if (kpTopic == null || data == null) {
                          return;
                        }

                        if (publishTopic) {
                          nt4Connection.nt4Client.publishTopic(kpTopic!);
                        }

                        nt4Connection.updateDataFromTopic(kpTopic!, data);
                      },
                    ),
                  ),
                  const Spacer(),
                ],
              ),
              // kI
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Spacer(),
                  Text('I', style: labelStyle),
                  const Spacer(),
                  Flexible(
                    flex: 5,
                    child: DialogTextInput(
                      textEditingController: kiTextController,
                      initialText: kiTextController!.text,
                      label: 'kI',
                      onSubmit: (value) {
                        bool publishTopic = kiTopic == null;

                        kiTopic ??= nt4Connection.getTopicFromName(kiTopicName);

                        double? data = double.tryParse(value);

                        if (kiTopic == null || data == null) {
                          return;
                        }

                        if (publishTopic) {
                          nt4Connection.nt4Client.publishTopic(kiTopic!);
                        }

                        nt4Connection.updateDataFromTopic(kiTopic!, data);
                      },
                    ),
                  ),
                  const Spacer(),
                ],
              ),
              // kD
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Spacer(),
                  Text('D', style: labelStyle),
                  const Spacer(),
                  Flexible(
                    flex: 5,
                    child: DialogTextInput(
                      textEditingController: kdTextController,
                      initialText: kdTextController!.text,
                      label: 'kD',
                      onSubmit: (value) {
                        bool publishTopic = kdTopic == null;

                        kdTopic ??= nt4Connection.getTopicFromName(kdTopicName);

                        double? data = double.tryParse(value);

                        if (kdTopic == null || data == null) {
                          return;
                        }

                        if (publishTopic) {
                          nt4Connection.nt4Client.publishTopic(kdTopic!);
                        }

                        nt4Connection.updateDataFromTopic(kdTopic!, data);
                      },
                    ),
                  ),
                  const Spacer(),
                ],
              ),
              Row(
                children: [
                  const Spacer(),
                  Text('Goal', style: labelStyle),
                  const Spacer(),
                  Flexible(
                    flex: 5,
                    child: DialogTextInput(
                      textEditingController: goalTextController,
                      initialText: goalTextController!.text,
                      label: 'Goal',
                      onSubmit: (value) {
                        bool publishTopic = goalTopic == null;

                        goalTopic ??=
                            nt4Connection.getTopicFromName(goalTopicName);

                        double? data = double.tryParse(value);

                        if (goalTopic == null || data == null) {
                          return;
                        }

                        if (publishTopic) {
                          nt4Connection.nt4Client.publishTopic(goalTopic!);
                        }

                        nt4Connection.updateDataFromTopic(goalTopic!, data);
                      },
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ],
          );
        });
  }
}
