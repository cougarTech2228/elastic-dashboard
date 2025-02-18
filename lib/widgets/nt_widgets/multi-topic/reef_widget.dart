import 'package:dot_cast/dot_cast.dart';
import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/single_topic/toggle_switch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_map/flutter_image_map.dart';
import 'package:provider/provider.dart';

enum Mode {
  unknown,
  algae,
  coral,
  coralAndAlgae,
}

enum ReefLocation { unknown, L1, L2_L, L2_R, L3_L, L3_R, L4_L, L4_R }

class ReefWidgetModel extends MultiTopicNTWidgetModel {
  @override
  String type = ReefWidget.widgetType;

  late NT4Subscription algaeLoadedSubscription;
  late NT4Subscription coralLoadedSubscription;
  late NT4Subscription executeCommandSubscription;
  late NT4Topic executeCommandTopic;

  late NT4Topic autoAlignTopic;
  late NT4Topic modeTopic;
  late NT4Topic destTopic;
  late NT4Topic reefSegmentTopic;
  late NT4Topic reefPostTopic;

  @override
  List<NT4Subscription> get subscriptions => [
        algaeLoadedSubscription,
        coralLoadedSubscription,
        executeCommandSubscription,
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

    autoAlignTopic = ntConnection.publishNewTopic('$topic/autoAlign', NT4TypeStr.kBool);
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

  bool isCoralLoaded() {
    return tryCast(coralLoadedSubscription.value) == true;
  }

  bool isAlgaeLoaded() {
    return tryCast(algaeLoadedSubscription.value) == true;
  }

  bool isCommandExecuting() {
    return tryCast(executeCommandSubscription.value) == true;
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
                            setState(() => model.autoAlignEnabled = !model.autoAlignEnabled);
                          },
                        ),
                        const Text("Auto Align Enabled"
                        )
                      ],
                    ),
                  ],
                ),
                Row(
                  spacing: 10,
                  children: [
                    Visibility(
                      visible: model.coralValid,
                      child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: model.getCoralColor(),
                            padding: const EdgeInsets.all(20.0),
                            fixedSize: const Size(200, 125),
                            side:
                                const BorderSide(width: 3, color: Colors.white),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30)),
                          ),
                          onPressed: () {
                            print('onCoralButtonPressed');
                            setState(() => model.onCoralButtonPressed());
                          },
                          child: Image.asset("assets/reef/coral.png")),
                    ),
                    Visibility(
                      visible: model.shouldShowAlgaeButton(),
                      child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: model.getAlgaeColor(),
                            padding: const EdgeInsets.all(20.0),
                            fixedSize: const Size(200, 125),
                            side:
                                const BorderSide(width: 3, color: Colors.white),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30)),
                          ),
                          onPressed: () {
                            print('onAlgaeButtonPressed');
                            setState(() => model.onAlgaeButtonPressed());
                          },
                          child: Image.asset("assets/reef/algae.png")),
                    ),
                    Visibility(
                      visible: model.coralAndAlgaeValid,
                      child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: model.getCoralAndAlgaeColor(),
                            padding: const EdgeInsets.all(20.0),
                            fixedSize: const Size(200, 125),
                            side:
                                const BorderSide(width: 3, color: Colors.white),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30)),
                          ),
                          onPressed: () {
                            print('onCoralAndAlgaeButtonPressed');
                            setState(
                                () => model.onCoralAndAlgaeButtonPressed());
                          },
                          child:
                              Image.asset("assets/reef/coral_and_algae.png")),
                    ),
                    const Spacer(),
                    Visibility(
                      visible: model.loaded,
                      child: ElevatedButton(
                          // Fire button
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange[400],
                            padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
                            minimumSize: const Size(20, 125),
                            side: const BorderSide(width: 3, color: Colors.white),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30)),
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
                    ),
                    ElevatedButton(
                        // GO button
                        style: ElevatedButton.styleFrom(
                          backgroundColor: model.getGoButtonColor(),
                          padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
                          minimumSize: const Size(20, 125),
                          side: const BorderSide(width: 3, color: Colors.white),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30)),
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
                        )),
                  ],
                ),
                Row(
                  spacing: 10,
                  children: [
                    Visibility(
                      visible: model.shouldShowReefAlgae(),
                      child: Container(
                        decoration: BoxDecoration(
                          color: model.reefAlgaeSelected
                              ? selectedColor
                              : unselectedColor,
                          borderRadius:
                              const BorderRadius.all(Radius.circular(15)),
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
                                rect: Rect.fromPoints(
                                    const Offset(0, 0), const Offset(264, 586)),
                                color: unselectedColor,
                                title: 'reef_algae',
                              )
                            ]),
                      ),
                    ),
                    Column(
                      spacing: 10,
                      children: [
                        Visibility(
                          visible: model.shouldShowFloorAlgae(),
                          child: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: model.floorAlgaeSelected
                                  ? selectedColor
                                  : unselectedColor,
                              borderRadius:
                                  const BorderRadius.all(Radius.circular(15)),
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            constraints: BoxConstraints.tight(Size(200, 200)),
                            child: Center(
                              child: ImageMap(
                                  image: Image.asset(
                                      "assets/reef/algae_floor.png",
                                      fit: BoxFit.scaleDown),
                                  onTap: (region) {
                                    setState(() => model.onAlgaeFloorPressed());
                                  },
                                  regions: [
                                    ImageMapRegion.fromRect(
                                      rect: Rect.fromPoints(const Offset(0, 0),
                                          const Offset(369, 297)),
                                      color: unselectedColor,
                                      title: 'algae_floor',
                                    )
                                  ]),
                            ),
                          ),
                        ),
                        Visibility(
                          visible: model.shouldShowAlgaeOnCoral(),
                          child: Container(
                            decoration: BoxDecoration(
                              color: model.algaeOnCoralSelected
                                  ? selectedColor
                                  : unselectedColor,
                              borderRadius:
                                  const BorderRadius.all(Radius.circular(15)),
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            constraints: BoxConstraints.tight(Size(200, 200)),
                            child: ImageMap(
                                image: Image.asset(
                                    "assets/reef/algae_on_coral.png",
                                    fit: BoxFit.scaleDown),
                                onTap: (region) {
                                  setState(() => model.onAlgaeOnCoralPressed());
                                },
                                regions: [
                                  ImageMapRegion.fromRect(
                                    rect: Rect.fromPoints(const Offset(0, 0),
                                        const Offset(253, 386)),
                                    color: unselectedColor,
                                    title: 'algae_on_coral',
                                  )
                                ]),
                          ),
                        ),
                      ],
                    ),
                    Visibility(
                      visible: model.shouldShowReef(),
                      child: Container(
                        constraints: BoxConstraints.tight(Size(500, 500)),
                        child: ImageMap(
                            image: Image.asset("assets/reef/reef.png",
                                fit: BoxFit.scaleDown),
                            onTap: (region) {
                              setState(() => model.onReefSegmentPressed(
                                  int.parse(region.title!)));
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
                    ),
                    Visibility(
                      visible: model.shouldShowPipes(),
                      child: Container(
                        constraints: BoxConstraints.tight(Size(300, 500)),
                        child: ImageMap(
                            image: Image.asset("assets/reef/pipes.png"),
                            onTap: (region) {
                              setState(
                                  () => model.onPipeSelected(region.title!));
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
                    ),
                    Visibility(
                      visible: model.shouldShowCoralLoader(),
                      child: Container(
                        decoration: BoxDecoration(
                          color: selectedColor,
                          borderRadius:
                              const BorderRadius.all(Radius.circular(15)),
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        constraints: BoxConstraints.tight(const Size(400, 400)),
                        child: Image.asset("assets/reef/coral_loader.png"),
                      ),
                    ),
                    Visibility(
                      visible: model.shouldShowProcessor(),
                      child: Container(
                        decoration: BoxDecoration(
                          color: model.processorSelected
                              ? selectedColor
                              : unselectedColor,
                          borderRadius:
                              const BorderRadius.all(Radius.circular(15)),
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
                                rect: Rect.fromPoints(
                                    const Offset(0, 0), const Offset(613, 545)),
                                color: unselectedColor,
                                title: 'Processor',
                              )
                            ]),
                      ),
                    ),
                    Visibility(
                      visible: model.shouldShowBarge(),
                      child: Container(
                        decoration: BoxDecoration(
                          color: model.bargeSelected
                              ? selectedColor
                              : unselectedColor,
                          borderRadius:
                              const BorderRadius.all(Radius.circular(15)),
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
                                rect: Rect.fromPoints(
                                    const Offset(0, 0), const Offset(555, 617)),
                                color: unselectedColor,
                                title: 'Barge',
                              )
                            ]),
                      ),
                    ),
                  ],
                ),
              ],
            );
          });
        });
  }
}
