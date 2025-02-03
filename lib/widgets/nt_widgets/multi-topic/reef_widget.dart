import 'package:dot_cast/dot_cast.dart';
import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_map/flutter_image_map.dart';
import 'package:provider/provider.dart';

class ReefWidgetModel extends MultiTopicNTWidgetModel {
  @override
  String type = ReefWidget.widgetType;

  String get algaeLoadedTopic => '$topic/algaeLoaded';
  late NT4Subscription algaeLoadedSubscription;
  
  String get coralLoadedTopic => '$topic/coralLoaded';
  late NT4Subscription coralLoadedSubscription;
  
  String get executeCommandTopic => '$topic/executeCommand';
  late NT4Subscription executeCommandSubscription;


  @override
  List<NT4Subscription> get subscriptions => [
    algaeLoadedSubscription,
    coralLoadedSubscription,
    executeCommandSubscription,
  ];


  int selectedRegion = 0;
  String? selectedPipe;
  bool coralValid = true;
  bool algaeValid = true;
  bool coralAndAlgaeValid = true;

  bool coralLoaderSelected = false;
  bool processorSelected = false;
  bool bargeSelected = false;
  
  bool showReef = true;
  bool showProcessor = false;
  bool showPipes = true;
  bool showCoralLoader = false;
  bool showBarge = false;

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
    algaeLoadedSubscription = ntConnection.subscribe(algaeLoadedTopic, super.period);
    coralLoadedSubscription = ntConnection.subscribe(coralLoadedTopic, super.period);
    executeCommandSubscription = ntConnection.subscribe(executeCommandTopic, super.period);
  }

  @override
  void resetSubscription() {
    for (NT4Subscription subscription in subscriptions) {
      ntConnection.unSubscribe(subscription);
    }

    initSubscriptions();

    super.resetSubscription();
  }

  String mode = "";
  
  Color getCoralAndAlgaeColor() {
    return mode == "coral_and_algae" ? Colors.green : Colors.black;
  }

  Color getAlgaeColor() {
    return mode == "algae" ? Colors.green : Colors.black;
  }

 Color getCoralColor() {
    return mode == "coral" ? Colors.green : Colors.black;
  }

  void onCoralButtonPressed() {
    print('onCoralButtonPressed');
    mode = "coral";
    _validateSelection();
  }

  void onAlgaeButtonPressed() {
    print('onAlgaeButtonPressed');
    mode = "algae";
    _validateSelection();
  }

  void onCoralAndAlgaeButtonPressed() {
    print('onCoralAndAlgaeButtonPressed.');
    if (coralAndAlgaeValid) {
      mode = "coral_and_algae";
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

  void _validateSelection() {

    if (mode == "algae") {
      coralLoaderSelected = false;
    }
    showPipes = mode == "coral";

    if (selectedRegion == 1 || selectedRegion == 3 || selectedRegion == 5) {
      // region 1,3,5 have high algae
      // we can't do coral and algae on high algae
      coralAndAlgaeValid = false;
    } else {
      coralAndAlgaeValid = true;
    }

    bool algaeLoaded = isAlgaeLoaded();
    bool coralLoaded = isCoralLoaded();

    if (coralAndAlgaeValid){
      coralAndAlgaeValid = !algaeLoaded;
    }

    if (coralAndAlgaeValid){
      coralAndAlgaeValid = coralLoaded;
    }

    coralValid = coralLoaded;
    algaeValid = !algaeLoaded;
    showCoralLoader = !coralLoaded;

    if (!coralLoaded && mode == "coral"){
      mode = "";
      showPipes = false;
    }

    
    if (coralLoaded){
      // if we just loaded a coral, and no mode is currently selected, select coral mode
      if( mode == "") {
        mode = "coral";
        showPipes = true;
      }

      // we have coral, unselect the loader, so the next time it shows up it's not already selected
      coralLoaderSelected = false;
    }

    showProcessor = algaeLoaded;
    showBarge = algaeLoaded;
    showReef = !algaeLoaded;

    if (algaeLoaded){
      showPipes = false;
      showCoralLoader = false;
      coralValid = false;
    }

  }

  void onReefSegmentPressed(int segment) {
    selectedRegion = segment;
    coralLoaderSelected = false;

    if (!isCoralLoaded()){
      mode = "algae";
    }

    _validateSelection();
  }

  void onPipeSelected(String pipe) {
    selectedPipe = pipe;
    _validateSelection();
  }

  void checkSubscriptions(){
    _validateSelection();
  }

  void onCoralLoaderSelected() {
    coralLoaderSelected = !coralLoaderSelected;
    if (coralLoaderSelected) {
      selectedRegion = 0;
      mode = "";
    }
    _validateSelection();
  }

  void onProcessorSelected() {
    processorSelected = !processorSelected;
    if (bargeSelected && processorSelected) {
      bargeSelected = false;
    }
  }

  void onBargeSelected() {
    bargeSelected = !bargeSelected;
    if (bargeSelected && processorSelected) {
      processorSelected = false;
    }
  }

  Color getGoButtonColor() {
    return isCommandExecuting() ? Color.fromRGBO(255, 0, 0, 0.498) : Color.fromRGBO(50, 200, 50, 0.5);
  }

  String getGoButtonLabel() {
    if (isCommandExecuting()) {
      return "Stop!";
    }
    return "GO!";
  }

  void onGoButtonPressed() {
    NT4Topic topic = ntConnection.getTopicFromSubscription(executeCommandSubscription)!;
    if (!ntConnection.isTopicPublished(topic)){
      ntConnection.publishTopic(topic);
    }
    
    ntConnection.updateDataFromTopic(ntConnection.getTopicFromSubscription(executeCommandSubscription)!, !isCommandExecuting());
  }
}

class ReefWidget extends NTWidget {
  static const String widgetType = 'ReefControl';
  static const selectedColor = Color.fromRGBO(50, 200, 50, 0.5);
  static const unselectedColor = Color.fromRGBO(50, 200, 50, 0);

  const ReefWidget({super.key}) : super();

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
                children: [
                  Visibility(
                    visible: model.showReef,
                    child: Container(
                      constraints: BoxConstraints.tight(Size(500, 500)),
                      child: ImageMap(
                          image: Image.asset("assets/reef/reef.png",
                              fit: BoxFit.scaleDown),
                          onTap: (region) {
                            setState(() => model.onReefSegmentPressed(int.parse(region.title!)));
                          },
                          regions: [
                            ImageMapRegion.fromPoly(
                              points: [
                                const Offset(305,281),
                                const Offset(156, 539),
                                const Offset(454, 539),
                              ],
                              color: model.selectedRegion == 1
                                  ? selectedColor
                                  : unselectedColor,
                              title: '1',
                            ),
                            ImageMapRegion.fromPoly(
                              points: [
                                const Offset(305,281),
                                const Offset(454,539),
                                const Offset(604,281),
                              ],
                              color: model.selectedRegion == 2
                                  ? selectedColor
                                  : unselectedColor,
                              title: '2',
                            ),
                            ImageMapRegion.fromPoly(
                              points: [
                                const Offset(305,281),
                                const Offset(604,281),
                                const Offset(455,22),
                              ],
                              color: model.selectedRegion == 3
                                  ? selectedColor
                                  : unselectedColor,
                              title: '3',
                            ),
                            ImageMapRegion.fromPoly(
                              points: [
                                const Offset(305,281),
                                const Offset(455,22),
                                const Offset(157,22),
                              ],
                              color: model.selectedRegion == 4
                                  ? selectedColor
                                  : unselectedColor,
                              title: '4',
                            ),
                            ImageMapRegion.fromPoly(
                              points: [
                                const Offset(305,281),
                                const Offset(157,22),
                                const Offset(6,281),
                              ],
                              color: model.selectedRegion == 5
                                  ? selectedColor
                                  : unselectedColor,
                              title: '5',
                            ),
                            ImageMapRegion.fromPoly(
                              points: [
                                const Offset(305,281),
                                const Offset(6,281),
                                const Offset(156,538),
                              ],
                              color: model.selectedRegion == 6
                                  ? selectedColor
                                  : unselectedColor,
                              title: '6',
                            ),
                          ]),
                    ),
                  ),
                  Visibility(
                    visible: model.showPipes,
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
                              color: model.selectedPipe == "4L"
                                  ? selectedColor
                                  : unselectedColor,
                              title: '4L',
                            ),
                            ImageMapRegion.fromCircle(
                              center: const Offset(347, 160),
                              radius: 100,
                              color: model.selectedPipe == "4R"
                                  ? selectedColor
                                  : unselectedColor,
                              title: '4R',
                            ),
                            ImageMapRegion.fromCircle(
                              center: const Offset(127, 421),
                              radius: 100,
                              color: model.selectedPipe == "3L"
                                  ? selectedColor
                                  : unselectedColor,
                              title: '3L',
                            ),
                            ImageMapRegion.fromCircle(
                              center: const Offset(334, 421),
                              radius: 100,
                              color: model.selectedPipe == "3R"
                                  ? selectedColor
                                  : unselectedColor,
                              title: '3R',
                            ),
                            ImageMapRegion.fromCircle(
                              center: const Offset(130, 633),
                              radius: 100,
                              color: model.selectedPipe == "2L"
                                  ? selectedColor
                                  : unselectedColor,
                              title: '2L',
                            ),
                            ImageMapRegion.fromCircle(
                              center: const Offset(334, 633),
                              radius: 100,
                              color: model.selectedPipe == "2R"
                                  ? selectedColor
                                  : unselectedColor,
                              title: '2R',
                            ),
                            ImageMapRegion.fromPoly(
                            points: [
                              const Offset(110,731),
                              const Offset(109,748),
                              const Offset(76,775),
                              const Offset(55,777),
                              const Offset(55,949),
                              const Offset(420,949),
                              const Offset(421,776),
                              const Offset(402,776),
                              const Offset(366,747),
                              const Offset(365,730),
                            ],
                            color: model.selectedPipe == "1"
                                ? selectedColor
                                : unselectedColor,
                            title: '1',
                          ),
                          ]),
                    ),
                  ),
                  Visibility(
                    visible: model.showCoralLoader,
                    child: Container(
                      constraints: BoxConstraints.tight(const Size(400, 400)),
                      child: ImageMap(
                          image: Image.asset("assets/reef/coral_loader.png"),
                          onTap: (region) {
                            setState(() => model.onCoralLoaderSelected());
                          },
                          regions: [
                            ImageMapRegion.fromPoly(
                            points: [
                              const Offset(31,467),
                              const Offset(33,219),
                              const Offset(101,10),
                              const Offset(418,74),
                              const Offset(497,108),
                              const Offset(497,509),
                              const Offset(347,535),
                            ],
                              color: model.coralLoaderSelected
                                  ? selectedColor
                                  : unselectedColor,
                              title: 'Loader',
                            )
                          ]),
                    ),
                  ),
                  Visibility(
                    visible: model.showProcessor,
                    child: Container(
                      constraints: BoxConstraints.tight(const Size(400, 400)),
                      child: ImageMap(
                          image: Image.asset("assets/reef/processor.png"),
                          onTap: (region) {
                            setState(() => model.onProcessorSelected());
                          },
                          regions: [
                            ImageMapRegion.fromRect(rect: Rect.fromPoints(const Offset(0,0), const Offset(613,545)),
                              color: model.processorSelected
                                  ? selectedColor
                                  : unselectedColor,
                              title: 'Processor',
                            )
                          ]),
                    ),
                  ),
                  Visibility(
                    visible: model.showBarge,
                    child: Container(
                      constraints: BoxConstraints.tight(const Size(400, 400)),
                      child: ImageMap(
                          image: Image.asset("assets/reef/barge.png"),
                          onTap: (region) {
                            setState(() => model.onBargeSelected());
                          },
                          regions: [
                            ImageMapRegion.fromRect(rect: Rect.fromPoints(const Offset(0,0), const Offset(555,617)),
                              color: model.bargeSelected
                                  ? selectedColor
                                  : unselectedColor,
                              title: 'Barge',
                            )
                          ]),
                    ),
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
                          side: const BorderSide(width: 3, color: Colors.white),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30)),
                        ),
                        onPressed:() {
                            print('onCoralButtonPressed');
                            setState(() => model.onCoralButtonPressed());
                        },
                        child: Image.asset("assets/reef/coral.png")),
                  ),
                  Visibility(
                    visible: model.algaeValid,
                    child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: model.getAlgaeColor(),
                          padding: const EdgeInsets.all(20.0),
                          fixedSize: const Size(200, 125),
                          side: const BorderSide(width: 3, color: Colors.white),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30)),
                        ),
                        onPressed:() {
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
                          side: const BorderSide(width: 3, color: Colors.white),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30)),
                        ),
                        onPressed:() {
                            print('onCoralAndAlgaeButtonPressed');
                            setState(() => model.onCoralAndAlgaeButtonPressed());
                        },
                        child: Image.asset("assets/reef/coral_and_algae.png")),
                  ),
                  const Spacer(),
                  ElevatedButton( // GO button
                    style: ElevatedButton.styleFrom(
                      backgroundColor: model.getGoButtonColor(),
                      padding: const EdgeInsets.fromLTRB(20,10,20,30),
                      minimumSize: const Size(20, 125),
                      
                      side: const BorderSide(width: 3, color: Colors.white),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                    ),
                    onPressed:() {
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
                    )
                  ),
                ],
              )
            ],
          );
        });
      }
    );
  }
}
