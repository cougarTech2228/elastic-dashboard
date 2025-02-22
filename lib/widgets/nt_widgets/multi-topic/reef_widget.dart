import 'package:dot_cast/dot_cast.dart';
import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_map/flutter_image_map.dart';
import 'package:geekyants_flutter_gauges/geekyants_flutter_gauges.dart';
import 'package:provider/provider.dart';
import 'package:material_symbols_icons/symbols.dart';

enum Mode {
  unknown,
  algae,
  coral,
  coralAndAlgae,
  cage,
}

enum ReefLocation { unknown, L1, L2_L, L2_R, L3_L, L3_R, L4_L, L4_R }

class ReefWidgetModel extends MultiTopicNTWidgetModel {
  @override
  String type = ReefWidget.widgetType;

  late NT4Subscription algaeLoadedSubscription;
  late NT4Subscription coralLoadedSubscription;
  late NT4Subscription executeCommandSubscription;
  late NT4Subscription climberAngleSubscription;
  late NT4Subscription climberAngleMinSubscription;
  late NT4Subscription climberAngleMaxSubscription;
  late NT4Subscription climberStateSubscription;
  late NT4Subscription climberLockSubscription;
  late NT4Topic executeCommandTopic;

  late NT4Topic autoAlignTopic;
  late NT4Topic modeTopic;
  late NT4Topic destTopic;
  late NT4Topic reefSegmentTopic;
  late NT4Topic reefPostTopic;
  late NT4Topic climberAngleTopic;

  @override
  List<NT4Subscription> get subscriptions => [
        algaeLoadedSubscription,
        coralLoadedSubscription,
        executeCommandSubscription,
        climberAngleSubscription,
        climberStateSubscription,
        climberAngleMinSubscription,
        climberAngleMaxSubscription,
        climberLockSubscription,
      ];

  int selectedReefSegment = 0;
  ReefLocation reefLocation = ReefLocation.unknown;
  bool coralValid = true;
  bool coralAndAlgaeValid = true;

  bool coralLoaderSelected = false;
  bool processorSelected = false;
  bool bargeSelected = false;
  bool floorAlgaeSelected = false;
  bool reefAlgaeSelected = false;
  bool algaeOnCoralSelected = false;
  bool cageSelected = false;

  bool autoAlignEnabled = true;

  String loadPieceText = "Load Piece";
  String selectDestinationText = "Select Destination";
  String instructionText = "";
  bool loaded = false;

  ReefWidgetModel({
    required super.ntConnection,
    required super.preferences,
    required super.topic,
    super.dataType,
    super.period,
  }) : super();

  ReefWidgetModel.fromJson({
    required super.ntConnection,
    required super.preferences,
    required super.jsonData,
  }) : super.fromJson();

  @override
  void init() {
    initSubscriptions();
    super.init();

    setAutoAlign(true);
  }

  void initSubscriptions() {
    algaeLoadedSubscription =
        ntConnection.subscribe('$topic/algaeLoaded', super.period);
    coralLoadedSubscription =
        ntConnection.subscribe('$topic/coralLoaded', super.period);
    executeCommandTopic =
        ntConnection.publishNewTopic('$topic/executeCommand', NT4TypeStr.kBool);
    executeCommandSubscription =
        ntConnection.subscribeAll(executeCommandTopic.name, super.period);
    climberAngleSubscription =
        ntConnection.subscribe('$topic/climberAngle', super.period);
    climberStateSubscription =
        ntConnection.subscribe('$topic/climberState', super.period);
    climberAngleMinSubscription =
        ntConnection.subscribe('$topic/climberAngleMin', super.period);
    climberAngleMaxSubscription =
        ntConnection.subscribe('$topic/climberAngleMax', super.period);
    climberLockSubscription =
        ntConnection.subscribe('$topic/climberLocked', super.period);

    autoAlignTopic =
        ntConnection.publishNewTopic('$topic/autoAlign', NT4TypeStr.kBool);
    modeTopic = ntConnection.publishNewTopic('$topic/mode', NT4TypeStr.kString);
    destTopic = ntConnection.publishNewTopic('$topic/dest', NT4TypeStr.kString);
    reefSegmentTopic =
        ntConnection.publishNewTopic('$topic/reefSegment', NT4TypeStr.kInt);
    reefPostTopic =
        ntConnection.publishNewTopic('$topic/reefPost', NT4TypeStr.kString);
  }

  @override
  void resetSubscription() {
    for (NT4Subscription subscription in subscriptions) {
      ntConnection.unSubscribe(subscription);
    }

    initSubscriptions();

    super.resetSubscription();
  }

  Mode mode = Mode.unknown;

  Color getCoralAndAlgaeColor() {
    return mode == Mode.coralAndAlgae ? Colors.green : Colors.black;
  }

  Color getAlgaeColor() {
    return mode == Mode.algae ? Colors.green : Colors.black;
  }

  Color getCoralColor() {
    return mode == Mode.coral ? Colors.green : Colors.black;
  }

  Color getCageColor() {
    return mode == Mode.cage ? Colors.green : Colors.black;
  }

  void setAutoAlign(bool enabled) {
    autoAlignEnabled = enabled;
    ntConnection.updateDataFromTopic(autoAlignTopic, enabled);
  }

  void onCoralButtonPressed() {
    print('onCoralButtonPressed');
    mode = Mode.coral;
    if (!loaded) {
      coralLoaderSelected = true;
    }
    _validateSelection();
  }

  void onAlgaeButtonPressed() {
    print('onAlgaeButtonPressed');
    mode = Mode.algae;
    reefLocation = ReefLocation.unknown;
    _validateSelection();
  }

  void onCoralAndAlgaeButtonPressed() {
    print('onCoralAndAlgaeButtonPressed.');
    if (coralAndAlgaeValid) {
      mode = Mode.coralAndAlgae;
      reefLocation = ReefLocation.unknown;
    }
    _validateSelection();
  }

  Color getClimberExtendColor() {
    if (isClimberExtending()) {
      return Colors.green;
    } else {
      return Colors.black;
    }
  }

  Color getClimberRetractColor() {
    if (isClimberRetracting()) {
      return Colors.green;
    } else {
      return Colors.black;
    }
  }

  void onClimberExtendButtonPressed() {
    ntConnection.updateDataFromTopic(modeTopic, "${mode.name}-extend");
    ntConnection.updateDataFromTopic(executeCommandTopic, true);
  }

  void onClimberRetractButtonPressed() {
    ntConnection.updateDataFromTopic(modeTopic, "${mode.name}-retract");
    ntConnection.updateDataFromTopic(executeCommandTopic, true);
  }

  void onCageButtonPressed() {
    mode = Mode.cage;
  }

  bool isCoralLoaded() {
    return tryCast(coralLoadedSubscription.value) == true;
  }

  bool isAlgaeLoaded() {
    return tryCast(algaeLoadedSubscription.value) == true;
  }

  bool isCommandExecuting() {
    return tryCast(executeCommandSubscription.value) == true;
  }

  bool isClimberExtending() {
    return tryCast(climberStateSubscription.value) == "EXTENDING";
  }

  bool isClimberRetracting() {
    return tryCast(climberStateSubscription.value) == "RETRACTING";
  }

  bool isClimberDisabled() {
    return tryCast(climberStateSubscription.value) == "DISABLED";
  }

  double getClimberAngle() {
    Object? val = climberAngleSubscription.value;
    if (val == null) {
      return 0;
    }
    double dVal = val as double;
    if (dVal < getClimberAngleMin()) {
      dVal = getClimberAngleMin();
    } else if (dVal > getClimberAngleMax()) {
      dVal = getClimberAngleMax();
    }

    return dVal;
  }

  double getClimberAngleMin() {
    Object? val = climberAngleMinSubscription.value;
    if (val == null) {
      return 0;
    }
    return val as double;
  }

  double getClimberAngleMax() {
    Object? val = climberAngleMaxSubscription.value;
    if (val == null) {
      return 0;
    }
    return val as double;
  }

  bool isClimberLocked() {
    return tryCast(climberLockSubscription.value) == true;
  }

  void onClimberLockButtonPressed() {
    if (isClimberLocked()) {
      ntConnection.updateDataFromTopic(modeTopic, "${mode.name}-unlock");
    } else {
      ntConnection.updateDataFromTopic(modeTopic, "${mode.name}-lock");
    }
    ntConnection.updateDataFromTopic(executeCommandTopic, true);
  }

  String getLockText() {
    return isClimberLocked() ? "Unlock" : "Lock";
  }

  void onCollapseButtonPressed() {
    ntConnection.updateDataFromTopic(modeTopic, "collapse");
    ntConnection.updateDataFromTopic(executeCommandTopic, true);
  }

  bool _validateSelection() {
    if (mode == Mode.algae) {
      coralLoaderSelected = false;
    }

    if (selectedReefSegment == 1 ||
        selectedReefSegment == 3 ||
        selectedReefSegment == 5) {
      // region 1,3,5 have high algae
      // we can't do coral and algae on high algae
      coralAndAlgaeValid = false;
    } else {
      coralAndAlgaeValid = true;
    }

    bool algaeLoaded = isAlgaeLoaded();
    bool coralLoaded = isCoralLoaded();

    if (algaeLoaded || coralLoaded) {
      loaded = true;
      instructionText = selectDestinationText;
    } else {
      loaded = false;
      instructionText = loadPieceText;
    }

    if (coralAndAlgaeValid) {
      coralAndAlgaeValid = !algaeLoaded;
    }

    if (coralAndAlgaeValid) {
      coralAndAlgaeValid = coralLoaded;
    }

    if (coralLoaded) {
      // if we just loaded a coral, and no mode is currently selected, select coral mode
      // if it's coral_and_algae, don't do anything
      if (mode == Mode.unknown || mode == Mode.algae) {
        mode = Mode.coral;
      }

      // we have coral, unselect the loader, so the next time it shows up it's not already selected
      coralLoaderSelected = false;

      reefAlgaeSelected = false;
      floorAlgaeSelected = false;
      algaeOnCoralSelected = false;
    }

    if (algaeLoaded) {
      //when algae is loaded, only algae mode is ever valid
      mode = Mode.algae;
      coralValid = false;
    } else {
      coralValid = true;
    }

    if (!loaded && (mode == Mode.unknown || mode == Mode.coralAndAlgae)) {
      // default to coral being selected
      mode = Mode.coral;
    }

    // return true if this is a valid selection to kick off a command
    bool valid = false;
    if (coralLoaderSelected ||
        bargeSelected ||
        processorSelected ||
        floorAlgaeSelected ||
        algaeOnCoralSelected) {
      // no additional options for these destinations
      valid = true;
    } else if (reefAlgaeSelected && selectedReefSegment != 0) {
      valid = true;
    }

    if (isAlgaeLoaded()) {
      if (processorSelected || bargeSelected) {
        valid = true;
      }
    }

    if (isCoralLoaded()) {
      if (mode == Mode.coral) {
        if (selectedReefSegment != 0 && reefLocation != ReefLocation.unknown) {
          valid = true;
        }
      } else if (mode == Mode.coralAndAlgae) {
        if (selectedReefSegment == 2 ||
            selectedReefSegment == 4 ||
            selectedReefSegment == 6) {
          valid = true;
        }
      }
    }
    return valid;
  }

  void onReefSegmentPressed(int segment) {
    if (!reefAlgaeSelected) {
      deselectAllDest();
    }

    selectedReefSegment = segment;
    coralLoaderSelected = false;

    if (!isCoralLoaded()) {
      mode = Mode.algae;
    }

    _validateSelection();
  }

  void onPipeSelected(String pipeName) {
    deselectAllDest();
    reefLocation = ReefLocation.values.firstWhere((e) => e.name == pipeName);
    _validateSelection();
  }

  void checkSubscriptions() {
    _validateSelection();
  }

  void deselectAllDest() {
    coralLoaderSelected = false;
    bargeSelected = false;
    processorSelected = false;

    reefAlgaeSelected = false;
    floorAlgaeSelected = false;
    algaeOnCoralSelected = false;
  }

  void onDestSelected(String dest) {
    deselectAllDest();
    reefLocation = ReefLocation.unknown;
    selectedReefSegment = 0;
    switch (dest) {
      case "coralLoader":
        mode = Mode.coral;
        coralLoaderSelected = true;
        break;
      case "processor":
        mode = Mode.algae;
        processorSelected = true;
        break;
      case "barge":
        mode = Mode.algae;
        bargeSelected = true;
        break;
      case "floorAlgae":
        mode = Mode.algae;
        floorAlgaeSelected = true;
        break;
    }
  }

  Color getGoButtonColor() {
    if (!_validateSelection()) {
      return ReefWidget.unselectedColor;
    }
    return isCommandExecuting()
        ? Color.fromRGBO(255, 0, 0, 0.498)
        : ReefWidget.selectedColor;
  }

  String getGoButtonLabel() {
    if (isCommandExecuting()) {
      return "Stop!";
    }
    return "GO!";
  }

  void onGoButtonPressed() {
    if (isCommandExecuting()) {
      ntConnection.updateDataFromTopic(executeCommandTopic, false);
      return;
    }
    if (!_validateSelection()) {
      return;
    }

    String dest;
    if (coralLoaderSelected) {
      dest = "coralStation";
    } else if (bargeSelected) {
      dest = "barge";
    } else if (processorSelected) {
      dest = "processor";
    } else if (floorAlgaeSelected) {
      dest = "floorAlgae";
    } else if (algaeOnCoralSelected) {
      dest = "algaeOnCoral";
    } else {
      dest = "reef";
    }

    ntConnection.updateDataFromTopic(autoAlignTopic, autoAlignEnabled);
    ntConnection.updateDataFromTopic(destTopic, dest);
    ntConnection.updateDataFromTopic(modeTopic, mode.name);
    ntConnection.updateDataFromTopic(reefSegmentTopic, selectedReefSegment);
    ntConnection.updateDataFromTopic(reefPostTopic, reefLocation.name);
    ntConnection.updateDataFromTopic(autoAlignTopic, autoAlignEnabled);
    ntConnection.updateDataFromTopic(
        executeCommandTopic, !isCommandExecuting());
  }

  void onFireButtonPressed() {
    ntConnection.updateDataFromTopic(executeCommandTopic, false);
    ntConnection.updateDataFromTopic(modeTopic, "fire");
    ntConnection.updateDataFromTopic(executeCommandTopic, true);
  }

  void onReefAlgaePressed() {
    // pickup an algae from the reef
    deselectAllDest();
    reefAlgaeSelected = true;
  }

  void onAlgaeFloorPressed() {
    // pickup an algae from the floor
    deselectAllDest();
    floorAlgaeSelected = true;
  }

  void onAlgaeOnCoralPressed() {
    // pickup an algae from the starting position sitting on top of the coral
    deselectAllDest();
    algaeOnCoralSelected = true;
  }

  bool shouldShowAlgaeButton() {
    return !isCoralLoaded();
  }

  bool shouldShowReefAlgae() {
    return !loaded && mode == Mode.algae;
  }

  bool shouldShowFloorAlgae() {
    return !loaded && mode == Mode.algae;
  }

  bool shouldShowAlgaeOnCoral() {
    return !loaded && mode == Mode.algae;
  }

  bool shouldShowCoralLoader() {
    bool shouldShow = !loaded && mode == Mode.coral;
    if (shouldShow) {
      // this is the only valid option, mark it as selected
      coralLoaderSelected = true;
    }
    return shouldShow;
  }

  bool shouldShowReef() {
    if (isAlgaeLoaded()) {
      return false;
    }

    return (loaded && mode == Mode.coral) ||
        (loaded && mode == Mode.coralAndAlgae) ||
        (!loaded && mode == Mode.algae && reefAlgaeSelected);
  }

  bool shouldShowProcessor() {
    return isAlgaeLoaded();
  }

  bool shouldShowBarge() {
    return isAlgaeLoaded();
  }

  bool shouldShowPipes() {
    if (isAlgaeLoaded()) {
      return false;
    }
    return loaded && mode == Mode.coral;
  }

  bool shouldClimberControls() {
    return mode == Mode.cage;
  }
}

class ReefWidget extends NTWidget {
  static const String widgetType = 'ReefControl';
  const ReefWidget({super.key}) : super();

  static const selectedColor = Color.fromRGBO(50, 200, 50, 0.5);
  static const unselectedColor = Color.fromRGBO(50, 200, 50, 0);

  @override
  Widget build(BuildContext context) {
    ReefWidgetModel model = cast(context.watch<NTWidgetModel>());
    return ListenableBuilder(
        listenable: Listenable.merge(model.subscriptions),
        builder: (context, child) {
          return StatefulBuilder(builder: (context, setState) {
            setState(() => model.checkSubscriptions());
            return Column(
              spacing: 10,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(),
                    Center(
                      child: Text(
                        model.instructionText,
                        style: const TextStyle(
                          fontSize: 70,
                          fontFamily: 'Arial Rounded MT Bold',
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Column(
                      children: [
                        Switch(
                          value: model.autoAlignEnabled,
                          onChanged: (bool value) {
                            setState(() => model.setAutoAlign(value));
                          },
                        ),
                        const Text("Auto Align Enabled")
                      ],
                    ),
                  ],
                ),
                Row(
                  // Top Button Row
                  spacing: 10,
                  children: [
                    coralButton(model, setState),
                    algaeButton(model, setState),
                    coralAndAlgaeButton(model, setState),
                    cageButton(model, setState),
                    collapseButton(model, setState),
                    const Spacer(),
                    fireButton(model, setState),
                  ],
                ),
                Row(
                  // Main Content container
                  spacing: 10,
                  children: [
                    reefAlgae(model, setState),
                    Column(
                      spacing: 10,
                      children: [
                        floorAlgae(model, setState),
                        algaeOnCoral(model, setState),
                      ],
                    ),
                    reef(model, setState),
                    pipes(model, setState),
                    coralLoader(model),
                    processor(model, setState),
                    barge(model, setState),
                    climberControls(model, setState, context),
                  ],
                ),
                Row(
                  spacing: 10,
                  children: [
                    const Spacer(),
                    goButton(model, setState),
                    const Spacer(),
                  ],
                )
              ],
            );
          });
        });
  }

  Widget climberControls(
      ReefWidgetModel model, StateSetter setState, BuildContext context) {
    return Visibility(
        visible: model.shouldClimberControls(),
        child: Row(
          spacing: 10,
          children: [
            ElevatedButton(
                // Climber Extend Button
                style: ElevatedButton.styleFrom(
                  backgroundColor: model.getClimberExtendColor(),
                  padding: const EdgeInsets.all(20.0),
                  fixedSize: const Size(250, 250),
                  side: const BorderSide(width: 3, color: Colors.white),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                ),
                onPressed: () {
                  setState(() => model.onClimberExtendButtonPressed());
                },
                child: Column(
                  children: [
                    Image.asset("assets/reef/climb_arrow.png",
                        width: 150, height: 150),
                    const Text(
                      "Extend",
                      style: TextStyle(
                        fontSize: 40,
                        fontFamily: 'Arial Rounded MT Bold',
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                )),
            ElevatedButton(
                // Climber Retract Button
                style: ElevatedButton.styleFrom(
                  backgroundColor: model.getClimberRetractColor(),
                  padding: const EdgeInsets.all(20.0),
                  fixedSize: const Size(250, 250),
                  side: const BorderSide(width: 3, color: Colors.white),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                ),
                onPressed: () {
                  setState(() => model.onClimberRetractButtonPressed());
                },
                child: Column(
                  children: [
                    Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..scale(-1.0, 1.0) // Flip horizontally
                          ..rotateZ(90 * 3.1415927 / 180), // Rotate 90 degrees,
                        child: Image.asset("assets/reef/climb_arrow.png",
                            width: 150, height: 150)),
                    const Text(
                      "Retract",
                      style: TextStyle(
                        fontSize: 40,
                        fontFamily: 'Arial Rounded MT Bold',
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                )),
            ElevatedButton(
                // Climber Retract Button
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  padding: const EdgeInsets.all(20.0),
                  fixedSize: const Size(250, 250),
                  side: const BorderSide(width: 3, color: Colors.white),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                ),
                onPressed: () {
                  setState(() => model.onClimberLockButtonPressed());
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.lock, size: 130),
                    Text(
                      model.getLockText(),
                      style: const TextStyle(
                        fontSize: 40,
                        fontFamily: 'Arial Rounded MT Bold',
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                )),
            Container(
              constraints: BoxConstraints.tight(const Size(250, 250)),
              child: Column(
                children: [
                  SizedBox(
                    width: 200, // Set the desired width
                    height: 200, // Set the desired height
                    child: RadialGauge(
                      track: RadialTrack(
                        start: model.getClimberAngleMin(),
                        end: model.getClimberAngleMax(),
                        color: const Color.fromRGBO(97, 97, 97, 1),
                        trackStyle: TrackStyle(
                          primaryRulerColor: Colors.grey,
                          secondaryRulerColor: Colors.grey,
                          showPrimaryRulers: false,
                          showSecondaryRulers: false,
                          showLabel: false,
                          labelStyle: Theme.of(context).textTheme.bodySmall,
                          rulersOffset: -5,
                          labelOffset: -10,
                        ),
                      ),
                      valueBar: [
                        RadialValueBar(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          value: model.getClimberAngle(),
                          startPosition: model.getClimberAngleMin(),
                        ),
                      ],
                    ),
                  ),
                  const Text(
                    "Climber Angle",
                    style: TextStyle(
                      fontSize: 30,
                      fontFamily: 'Arial Rounded MT Bold',
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ));
  }

  Widget barge(ReefWidgetModel model, StateSetter setState) {
    return Visibility(
      visible: model.shouldShowBarge(),
      child: Container(
        decoration: BoxDecoration(
          color: model.bargeSelected ? selectedColor : unselectedColor,
          borderRadius: const BorderRadius.all(Radius.circular(15)),
          border: Border.all(color: Colors.white, width: 2),
        ),
        constraints: BoxConstraints.tight(const Size(400, 400)),
        child: ImageMap(
            image: Image.asset("assets/reef/barge.png"),
            onTap: (region) {
              setState(() => model.onDestSelected("barge"));
            },
            regions: [
              ImageMapRegion.fromRect(
                rect:
                    Rect.fromPoints(const Offset(0, 0), const Offset(555, 617)),
                color: unselectedColor,
                title: 'Barge',
              )
            ]),
      ),
    );
  }

  Widget processor(ReefWidgetModel model, StateSetter setState) {
    return Visibility(
      visible: model.shouldShowProcessor(),
      child: Container(
        decoration: BoxDecoration(
          color: model.processorSelected ? selectedColor : unselectedColor,
          borderRadius: const BorderRadius.all(Radius.circular(15)),
          border: Border.all(color: Colors.white, width: 2),
        ),
        constraints: BoxConstraints.tight(const Size(400, 400)),
        child: ImageMap(
            image: Image.asset("assets/reef/processor.png"),
            onTap: (region) {
              setState(() => model.onDestSelected("processor"));
            },
            regions: [
              ImageMapRegion.fromRect(
                rect:
                    Rect.fromPoints(const Offset(0, 0), const Offset(613, 545)),
                color: unselectedColor,
                title: 'Processor',
              )
            ]),
      ),
    );
  }

  Widget coralLoader(ReefWidgetModel model) {
    return Visibility(
      visible: model.shouldShowCoralLoader(),
      child: Container(
        decoration: BoxDecoration(
          color: selectedColor,
          borderRadius: const BorderRadius.all(Radius.circular(15)),
          border: Border.all(color: Colors.white, width: 2),
        ),
        constraints: BoxConstraints.tight(const Size(400, 400)),
        child: Image.asset("assets/reef/coral_loader.png"),
      ),
    );
  }

  Widget pipes(ReefWidgetModel model, StateSetter setState) {
    return Visibility(
      visible: model.shouldShowPipes(),
      child: Container(
        constraints: BoxConstraints.tight(Size(300, 500)),
        child: ImageMap(
            image: Image.asset("assets/reef/pipes.png"),
            onTap: (region) {
              setState(() => model.onPipeSelected(region.title!));
            },
            regions: [
              ImageMapRegion.fromCircle(
                center: const Offset(116, 160),
                radius: 100,
                color: model.reefLocation == ReefLocation.L4_L
                    ? selectedColor
                    : unselectedColor,
                title: ReefLocation.L4_L.name,
              ),
              ImageMapRegion.fromCircle(
                center: const Offset(347, 160),
                radius: 100,
                color: model.reefLocation == ReefLocation.L4_R
                    ? selectedColor
                    : unselectedColor,
                title: ReefLocation.L4_R.name,
              ),
              ImageMapRegion.fromCircle(
                center: const Offset(127, 421),
                radius: 100,
                color: model.reefLocation == ReefLocation.L3_L
                    ? selectedColor
                    : unselectedColor,
                title: ReefLocation.L3_L.name,
              ),
              ImageMapRegion.fromCircle(
                center: const Offset(334, 421),
                radius: 100,
                color: model.reefLocation == ReefLocation.L3_R
                    ? selectedColor
                    : unselectedColor,
                title: ReefLocation.L3_R.name,
              ),
              ImageMapRegion.fromCircle(
                center: const Offset(130, 633),
                radius: 100,
                color: model.reefLocation == ReefLocation.L2_L
                    ? selectedColor
                    : unselectedColor,
                title: ReefLocation.L2_L.name,
              ),
              ImageMapRegion.fromCircle(
                center: const Offset(334, 633),
                radius: 100,
                color: model.reefLocation == ReefLocation.L2_R
                    ? selectedColor
                    : unselectedColor,
                title: ReefLocation.L2_R.name,
              ),
              ImageMapRegion.fromPoly(
                points: [
                  const Offset(110, 731),
                  const Offset(109, 748),
                  const Offset(76, 775),
                  const Offset(55, 777),
                  const Offset(55, 949),
                  const Offset(420, 949),
                  const Offset(421, 776),
                  const Offset(402, 776),
                  const Offset(366, 747),
                  const Offset(365, 730),
                ],
                color: model.reefLocation == ReefLocation.L1
                    ? selectedColor
                    : unselectedColor,
                title: ReefLocation.L1.name,
              ),
            ]),
      ),
    );
  }

  Widget reef(ReefWidgetModel model, StateSetter setState) {
    return Visibility(
      visible: model.shouldShowReef(),
      child: Container(
        constraints: BoxConstraints.tight(Size(500, 500)),
        child: ImageMap(
            image: Image.asset("assets/reef/reef.png", fit: BoxFit.scaleDown),
            onTap: (region) {
              setState(
                  () => model.onReefSegmentPressed(int.parse(region.title!)));
            },
            regions: [
              ImageMapRegion.fromPoly(
                points: [
                  const Offset(305, 281),
                  const Offset(156, 539),
                  const Offset(454, 539),
                ],
                color: model.selectedReefSegment == 1
                    ? selectedColor
                    : unselectedColor,
                title: '1',
              ),
              ImageMapRegion.fromPoly(
                points: [
                  const Offset(305, 281),
                  const Offset(454, 539),
                  const Offset(604, 281),
                ],
                color: model.selectedReefSegment == 2
                    ? selectedColor
                    : unselectedColor,
                title: '2',
              ),
              ImageMapRegion.fromPoly(
                points: [
                  const Offset(305, 281),
                  const Offset(604, 281),
                  const Offset(455, 22),
                ],
                color: model.selectedReefSegment == 3
                    ? selectedColor
                    : unselectedColor,
                title: '3',
              ),
              ImageMapRegion.fromPoly(
                points: [
                  const Offset(305, 281),
                  const Offset(455, 22),
                  const Offset(157, 22),
                ],
                color: model.selectedReefSegment == 4
                    ? selectedColor
                    : unselectedColor,
                title: '4',
              ),
              ImageMapRegion.fromPoly(
                points: [
                  const Offset(305, 281),
                  const Offset(157, 22),
                  const Offset(6, 281),
                ],
                color: model.selectedReefSegment == 5
                    ? selectedColor
                    : unselectedColor,
                title: '5',
              ),
              ImageMapRegion.fromPoly(
                points: [
                  const Offset(305, 281),
                  const Offset(6, 281),
                  const Offset(156, 538),
                ],
                color: model.selectedReefSegment == 6
                    ? selectedColor
                    : unselectedColor,
                title: '6',
              ),
            ]),
      ),
    );
  }

  Widget algaeOnCoral(ReefWidgetModel model, StateSetter setState) {
    return Visibility(
      visible: model.shouldShowAlgaeOnCoral(),
      child: Container(
        decoration: BoxDecoration(
          color: model.algaeOnCoralSelected ? selectedColor : unselectedColor,
          borderRadius: const BorderRadius.all(Radius.circular(15)),
          border: Border.all(color: Colors.white, width: 2),
        ),
        constraints: BoxConstraints.tight(Size(200, 200)),
        child: ImageMap(
            image: Image.asset("assets/reef/algae_on_coral.png",
                fit: BoxFit.scaleDown),
            onTap: (region) {
              setState(() => model.onAlgaeOnCoralPressed());
            },
            regions: [
              ImageMapRegion.fromRect(
                rect:
                    Rect.fromPoints(const Offset(0, 0), const Offset(253, 386)),
                color: unselectedColor,
                title: 'algae_on_coral',
              )
            ]),
      ),
    );
  }

  Widget floorAlgae(ReefWidgetModel model, StateSetter setState) {
    return Visibility(
      visible: model.shouldShowFloorAlgae(),
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: model.floorAlgaeSelected ? selectedColor : unselectedColor,
          borderRadius: const BorderRadius.all(Radius.circular(15)),
          border: Border.all(color: Colors.white, width: 2),
        ),
        constraints: BoxConstraints.tight(Size(200, 200)),
        child: Center(
          child: ImageMap(
              image: Image.asset("assets/reef/algae_floor.png",
                  fit: BoxFit.scaleDown),
              onTap: (region) {
                setState(() => model.onAlgaeFloorPressed());
              },
              regions: [
                ImageMapRegion.fromRect(
                  rect: Rect.fromPoints(
                      const Offset(0, 0), const Offset(369, 297)),
                  color: unselectedColor,
                  title: 'algae_floor',
                )
              ]),
        ),
      ),
    );
  }

  Widget reefAlgae(ReefWidgetModel model, StateSetter setState) {
    return Visibility(
      visible: model.shouldShowReefAlgae(),
      child: Container(
        decoration: BoxDecoration(
          color: model.reefAlgaeSelected ? selectedColor : unselectedColor,
          borderRadius: const BorderRadius.all(Radius.circular(15)),
          border: Border.all(color: Colors.white, width: 2),
        ),
        constraints: BoxConstraints.tight(const Size(200, 500)),
        child: ImageMap(
            image: Image.asset("assets/reef/reef_algae.png",
                fit: BoxFit.scaleDown),
            onTap: (region) {
              setState(() => model.onReefAlgaePressed());
            },
            regions: [
              ImageMapRegion.fromRect(
                rect:
                    Rect.fromPoints(const Offset(0, 0), const Offset(264, 586)),
                color: unselectedColor,
                title: 'reef_algae',
              )
            ]),
      ),
    );
  }

  Widget goButton(ReefWidgetModel model, StateSetter setState) {
    return ElevatedButton(
        // GO button
        style: ElevatedButton.styleFrom(
          backgroundColor: model.getGoButtonColor(),
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
          minimumSize: const Size(20, 125),
          side: const BorderSide(width: 3, color: Colors.white),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ),
        onPressed: () {
          setState(() => model.onGoButtonPressed());
        },
        child: Text(
          model.getGoButtonLabel(),
          style: const TextStyle(
            fontSize: 70,
            fontFamily: 'Arial Rounded MT Bold',
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ));
  }

  Widget coralButton(ReefWidgetModel model, StateSetter setState) {
    return Visibility(
      visible: model.coralValid,
      child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: model.getCoralColor(),
            padding: const EdgeInsets.all(20.0),
            fixedSize: const Size(200, 125),
            side: const BorderSide(width: 3, color: Colors.white),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          ),
          onPressed: () {
            print('onCoralButtonPressed');
            setState(() => model.onCoralButtonPressed());
          },
          child: Image.asset("assets/reef/coral.png")),
    );
  }

  Widget algaeButton(ReefWidgetModel model, StateSetter setState) {
    return Visibility(
      visible: model.shouldShowAlgaeButton(),
      child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: model.getAlgaeColor(),
            padding: const EdgeInsets.all(20.0),
            fixedSize: const Size(200, 125),
            side: const BorderSide(width: 3, color: Colors.white),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          ),
          onPressed: () {
            print('onAlgaeButtonPressed');
            setState(() => model.onAlgaeButtonPressed());
          },
          child: Image.asset("assets/reef/algae.png")),
    );
  }

  Widget coralAndAlgaeButton(ReefWidgetModel model, StateSetter setState) {
    return Visibility(
      visible: model.coralAndAlgaeValid,
      child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: model.getCoralAndAlgaeColor(),
            padding: const EdgeInsets.all(20.0),
            fixedSize: const Size(200, 125),
            side: const BorderSide(width: 3, color: Colors.white),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          ),
          onPressed: () {
            print('onCoralAndAlgaeButtonPressed');
            setState(() => model.onCoralAndAlgaeButtonPressed());
          },
          child: Image.asset("assets/reef/coral_and_algae.png")),
    );
  }

  Widget cageButton(ReefWidgetModel model, StateSetter setState) {
    return ElevatedButton(
        // Climber Button
        style: ElevatedButton.styleFrom(
          backgroundColor: model.getCageColor(),
          padding: const EdgeInsets.all(20.0),
          fixedSize: const Size(200, 125),
          side: const BorderSide(width: 3, color: Colors.white),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ),
        onPressed: () {
          setState(() => model.onCageButtonPressed());
        },
        child: Image.asset("assets/reef/cage.png"));
  }

  Widget collapseButton(ReefWidgetModel model, StateSetter setState) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: model.getCageColor(),
        padding: const EdgeInsets.all(20.0),
        fixedSize: const Size(200, 125),
        side: const BorderSide(width: 3, color: Colors.white),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
      onPressed: () {
        setState(() => model.onCollapseButtonPressed());
      },
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon( Symbols.stat_minus_3_rounded, size: 70),
          Text(
            "Collapse",
            style: TextStyle(
              fontSize: 20,
              fontFamily: 'Arial Rounded MT Bold',
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      )
    );
  }

  Widget fireButton(ReefWidgetModel model, StateSetter setState) {
    return Visibility(
      visible: model.loaded,
      child: ElevatedButton(
          // Fire button
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange[400],
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
            minimumSize: const Size(20, 125),
            side: const BorderSide(width: 3, color: Colors.white),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          ),
          onPressed: () {
            setState(() => model.onFireButtonPressed());
          },
          child: const Text(
            "Fire!",
            style: TextStyle(
              fontSize: 70,
              fontFamily: 'Arial Rounded MT Bold',
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          )),
    );
  }
}
