import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:location/location.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:material_floating_search_bar_2/material_floating_search_bar_2.dart';
import 'package:sig_grupL/utils/api_google.dart';

import '../components/google_maps.dart';
import '../controllers/apiController.dart';
import '../utils/maps_style.dart';

class Home extends StatefulWidget {
  const Home({Key? key}) : super(key: key);

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final Completer<GoogleMapController> _completer = Completer();
  LocationData? currentLocation;
  bool mostrarMarcador = true;
  Set<Marker> markers = {};

  List<LatLng> polylineCoordinates = [];
  double inicioLatitude = 0;
  double inicioLongitude = 0;
  bool finMarker = false;
  bool miUbicacion = false;
  bool dosPuntos = false;
  bool bandera = false;

  String description = '';
  String group = '';
  String initials = '';
  double totalDistance = 0.0;

  Future<GoogleMapController> get _mapController async {
    return await _completer.future;
  }

  _init() async {
    (await _mapController).setMapStyle(jsonEncode(mapStyle));
  }

  void getCurrentLocation() async {
    Location location = Location();

    location.getLocation().then((LocationData locationData) {
      setState(() {
        currentLocation = locationData;
      });
    });
  }

  Future<LatLng> getLatLng(ScreenCoordinate screenCoordinate) async {
    final GoogleMapController controller = await _mapController;
    return controller.getLatLng(screenCoordinate);
  }

  void addMarker(LatLng position) async {
    if (bandera) {
      removeMarker(markers.last.markerId);
      bandera = false;
    }

    if (dosPuntos == false) {
      final ByteData imageData =
          await rootBundle.load('assets/icons/mark_start.png');
      final Uint8List bytes = imageData.buffer.asUint8List();
      final img.Image? originalImage = img.decodeImage(bytes);
      final img.Image resizedImage =
          img.copyResize(originalImage!, width: 88, height: 140);
      final resizedImageData = img.encodePng(resizedImage);
      final BitmapDescriptor bitmapDescriptor =
          BitmapDescriptor.fromBytes(resizedImageData);
      final newMarker = Marker(
        markerId: MarkerId(DateTime.now().millisecondsSinceEpoch.toString()),
        position: position,
        icon: bitmapDescriptor,
      );
      mostrarMarcador = true;
      /* if (miUbicacion) {
        final GoogleMapController controller = await _mapController;
        controller.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(
                currentLocation!.latitude!,
                currentLocation!.longitude!,
              ),
              zoom: 14.5,
            ),
          ),
        );
      } */
      setState(() {
        markers.add(newMarker);
        if (dosPuntos) createPolylines(position);
      });
    } else {
      final ByteData imageData = await rootBundle.load('assets/icons/mark.png');
      final Uint8List bytes = imageData.buffer.asUint8List();
      final img.Image? originalImage = img.decodeImage(bytes);
      final img.Image resizedImage =
          img.copyResize(originalImage!, width: 88, height: 140);
      final resizedImageData = img.encodePng(resizedImage);
      final BitmapDescriptor bitmapDescriptor =
          BitmapDescriptor.fromBytes(resizedImageData);
      final newMarker = Marker(
        markerId: MarkerId(DateTime.now().millisecondsSinceEpoch.toString()),
        position: position,
        icon: bitmapDescriptor,
      );
      mostrarMarcador = true;
      /* if (miUbicacion) {
        final GoogleMapController controller = await _mapController;
        controller.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(
                currentLocation!.latitude!,
                currentLocation!.longitude!,
              ),
              zoom: 14.5,
            ),
          ),
        );
      } */
      setState(() {
        markers.add(newMarker);
        if (dosPuntos) createPolylines(position);
      });
    }
  }

  void createPolylines(LatLng position) async {
    PolylinePoints polylinePoints = PolylinePoints();

    PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
      apiGoogle,
      PointLatLng(inicioLatitude, inicioLongitude),
      PointLatLng(position.latitude, position.longitude),
    );

    if (result.status == 'OK') {
      for (var point in result.points) {
        polylineCoordinates.add(LatLng(point.latitude, point.longitude));
      }

      calculatePolylineDistance();
    }

    bandera = true;

    setState(() {});
  }

  void calculatePolylineDistance() {
    totalDistance = 0.0;

    for (int i = 0; i < polylineCoordinates.length - 1; i++) {
      final LatLng start = polylineCoordinates[i];
      final LatLng end = polylineCoordinates[i + 1];

      final double segmentDistance = calculateDistance(start, end);
      totalDistance += segmentDistance;
    }

    totalDistance = double.parse(totalDistance.toStringAsFixed(2));

    if (kDebugMode) {
      print('Distancia total de la polilínea: $totalDistance km');
    }
  }

  double calculateDistance(LatLng start, LatLng end) {
    const int earthRadius = 6371; // Radio de la Tierra en kilómetros

    final double lat1 = start.latitude * pi / 180;
    final double lon1 = start.longitude * pi / 180;
    final double lat2 = end.latitude * pi / 180;
    final double lon2 = end.longitude * pi / 180;

    final double dLat = lat2 - lat1;
    final double dLon = lon2 - lon1;

    final double a =
        pow(sin(dLat / 2), 2) + cos(lat1) * cos(lat2) * pow(sin(dLon / 2), 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    final double distance = earthRadius * c;
    return distance;
  }

  void removeMarker(MarkerId markerId) {
    setState(() {
      markers.removeWhere((marker) => marker.markerId == markerId);
      polylineCoordinates.clear();
      mostrarMarcador = true;
    });
  }

  List<Map<String, Object>> jsonData = [];
  List<String> datosDescription = [];
  List<String> datosGroup = [];

  void search(String query) {
    final matchQuery = getMatchedResults(query);
    final matchQueryGroup = getMatchedResultsGroup(query);
    setState(() {
      datosDescription = matchQuery;
      datosGroup = matchQueryGroup;
      if (kDebugMode) {
        print(datosDescription);
      }
      if (kDebugMode) {
        print(datosGroup);
      }
    });
  }

  List<String> getMatchedResults(String query) {
    if (query.isEmpty) {
      return [];
    }

    return jsonData
        .map((item) => item['description'] as String)
        .where((item) => item.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  List<String> getMatchedResultsGroup(String query) {
    if (query.isEmpty) {
      return [];
    }

    List<String> group = [];
    for (var i = 0; i < jsonData.length; i++) {
      String description = jsonData[i]['description'] as String;
      if (description.toLowerCase().contains(query.toLowerCase())) {
        group.add(jsonData[i]['group'] as String);
      }
    }
    return group;
  }

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    _init();
    getCurrentLocation();
    ApiController().leerJSON().then((data) {
      setState(() {
        jsonData = data;
        datosDescription =
            jsonData.map((item) => item['description'] as String).toList();
        datosGroup = jsonData.map((item) => item['group'] as String).toList();
      });
    }).catchError((error) {
      // Manejar el error de lectura del JSON
      if (kDebugMode) {
        print("Error: $error");
      }
    });
    super.initState();
  }

  @override
  void dispose() {
    // Dispose el TextEditingController al finalizar
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          if (currentLocation == null)
            const Center(
              child: CircularProgressIndicator(),
            )
          else
            SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                    target: LatLng(
                      currentLocation!.latitude!,
                      currentLocation!.longitude!,
                    ),
                    zoom: 14.5),
                onMapCreated: (GoogleMapController controller) {
                  _completer.complete(controller);
                },
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                trafficEnabled: false,
                mapType: MapType.normal,
                compassEnabled: false,
                markers: markers,
                polylines: {
                  Polyline(
                    polylineId: const PolylineId('polyLine'),
                    color: Colors.blue,
                    points: polylineCoordinates,
                    width: 5,
                  ),
                },
              ),
            ),
          if (dosPuntos)
            Container(
              alignment: Alignment.bottomCenter,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: IntrinsicHeight(
                  child: Container(
                    width: double.infinity,
                    color: Colors.white,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment
                          .center, // Centrar los elementos horizontalmente
                      children: [
                        Text(
                          "Distancia: $totalDistance km",
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        Text(
                          "Grupo: $group",
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        Text(
                          "Iniciales: $initials",
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        Text(
                          "Descripcion: $description",
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (finMarker == false && mostrarMarcador == true)
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: double.infinity,
                height: 60,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30)),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(
                      left: 25, right: 25, top: 10, bottom: 10),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: const Text('Marcar Inicio'),
                    onPressed: () {
                      showModalBottomSheet(
                          context: context,
                          builder: (BuildContext context) {
                            return Container(
                              decoration: const BoxDecoration(
                                color: Colors.white,
                              ),
                              height: 140,
                              child: Align(
                                alignment: Alignment.topCenter,
                                child: Column(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: ElevatedButton(
                                        onPressed: () {
                                          mostrarMarcador = false;
                                          setState(() {});
                                          Navigator.of(context).pop();
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.white,
                                          foregroundColor: Colors.black,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          minimumSize:
                                              const Size(double.infinity, 50),
                                        ),
                                        child: const Text('Marcar en el mapa'),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: ElevatedButton(
                                          onPressed: () {
                                            inicioLatitude =
                                                currentLocation!.latitude!;
                                            inicioLongitude = currentLocation!
                                                .longitude!; //currentLocation!.longitude!;
                                            mostrarMarcador = true;
                                            miUbicacion = true;
                                            bandera = false;
                                            addMarker(LatLng(
                                              currentLocation!.latitude!,
                                              currentLocation!.longitude!,
                                            ));
                                            finMarker = true;
                                            Navigator.of(context).pop();
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.white,
                                            foregroundColor: Colors.black,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            minimumSize:
                                                const Size(double.infinity, 50),
                                          ),
                                          child:
                                              const Text("Desde mi ubicación")),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          });
                    },
                  ),
                ),
              ),
            ),
          if (mostrarMarcador == false)
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: double.infinity,
                height: 130,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30)),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(
                      left: 25, right: 25, top: 10, bottom: 10),
                  child: Column(
                    children: [
                      ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            minimumSize: const Size(double.infinity, 50),
                          ),
                          child: const Text('Aceptar'),
                          onPressed: () {
                            _completer.future
                                .then((GoogleMapController controller) {
                              controller
                                  .getVisibleRegion()
                                  .then((LatLngBounds bounds) {
                                final LatLng centerLatLng = LatLng(
                                  (bounds.northeast.latitude +
                                          bounds.southwest.latitude) /
                                      2,
                                  (bounds.northeast.longitude +
                                          bounds.southwest.longitude) /
                                      2,
                                );
                                inicioLatitude = centerLatLng.latitude;
                                inicioLongitude = centerLatLng.longitude;
                                dosPuntos = false;
                                mostrarMarcador = false;
                                bandera = false;
                                finMarker = true;
                                addMarker(centerLatLng);
                              });
                            });
                          }),
                      const SizedBox(
                        height: 10,
                      ),
                      ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            minimumSize: const Size(double.infinity, 50),
                          ),
                          child: const Text('Cancelar'),
                          onPressed: () {
                            mostrarMarcador = true;
                            setState(() {});
                          }),
                    ],
                  ),
                ),
              ),
            ),
          if (mostrarMarcador == false)
            Center(
              child: Opacity(
                opacity: markers.isEmpty ? 1.0 : 0.0,
                child: Image.asset(
                  'assets/icons/mark_start.png',
                  width: 50,
                  height: 50,
                ),
              ),
            ),
          if (finMarker == true)
            Container(
              margin: const EdgeInsets.only(top: 100, right: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  FloatingActionButton(
                    heroTag: 'add_location',
                    backgroundColor: Colors.red,
                    onPressed: () {
                      _completer.future.then((GoogleMapController controller) {
                        controller
                            .getVisibleRegion()
                            .then((LatLngBounds bounds) {
                          if (dosPuntos == false) {
                            miUbicacion = false;
                            finMarker = false;
                            dosPuntos = false;
                            removeMarker(markers.first.markerId);
                          } else {
                            removeMarker(markers.first.markerId);
                            removeMarker(markers.last.markerId);
                            mostrarMarcador = true;
                            dosPuntos = false;
                            finMarker = false;
                          }
                        });
                      });
                    },
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                ],
              ),
            ),
          buildFloatingSearchBar(context),
        ],
      ),
    );
  }

  final GlobalKey<FloatingSearchBarState> _searchBarKey =
      GlobalKey<FloatingSearchBarState>();

  Widget buildFloatingSearchBar(BuildContext context) {
    final isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;

    return FloatingSearchBar(
      key: _searchBarKey,
      hint: 'Buscar lugar',
      scrollPadding: const EdgeInsets.only(top: 16, bottom: 56),
      transitionDuration: const Duration(milliseconds: 500),
      transitionCurve: Curves.easeInOut,
      physics: const BouncingScrollPhysics(),
      axisAlignment: isPortrait ? 0.0 : -1.0,
      openAxisAlignment: 0.0,
      width: isPortrait ? 600 : 500,
      debounceDelay: const Duration(milliseconds: 400),
      borderRadius: BorderRadius.circular(30),
      onQueryChanged: (query) {
        // Call your model, bloc, controller here.
        search(query);
      },
      transition: CircularFloatingSearchBarTransition(),
      actions: [
        FloatingSearchBarAction(
          showIfOpened: false,
          child: CircularButton(
            icon: const Icon(Icons.place),
            onPressed: () {},
          ),
        ),
        FloatingSearchBarAction.searchToClear(
          showIfClosed: false,
        ),
      ],
      builder: (context, transition) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Material(
            color: Colors.white,
            elevation: 4.0,
            child: ListView.builder(
              shrinkWrap: true, // Ajusta el tamaño al contenido
              itemCount: datosDescription.length,
              padding: EdgeInsets.zero,
              itemBuilder: (context, index) {
                final itemDescrip = datosDescription[index];
                final itemGroup = datosGroup[index];
                return ListTile(
                  title: Text(itemDescrip),
                  subtitle: Text(itemGroup), // Aquí puedes poner el grupo
                  iconColor: Colors.blue,
                  dense: true,
                  /* icon ojo */
                  leading: const Icon(
                    Icons.location_on,
                  ),
                  onTap: () {
                    if (markers.isNotEmpty) {
                      final data = jsonData.firstWhere(
                        (element) => element['description'] == itemDescrip,
                        orElse: () => {
                          'description': '',
                          'latitude': '0',
                          'longitude': '0',
                        },
                      );
                      final position = LatLng(
                        double.parse(data['latitude'].toString()),
                        double.parse(data['longitude'].toString()),
                      );
                      // Aquí puedes hacer lo que necesites con las coordenadas
                      dosPuntos = true;
                      miUbicacion = false;
                      description = data['description'].toString();
                      group = data['group'].toString();
                      initials = data['initials'].toString();
                      // Por ejemplo, agregar un marcador
                      addMarker(position);
                      // Cerrar el buscador y volver a la pantalla principal
                      setState(() {
                        search('');
                        _searchController.clear();
                        /* Ocultar teclado */
                        FocusScope.of(context).unfocus();
                      });
                      _searchBarKey.currentState?.close();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('No hay marcadores'),
                        ),
                      );
                    }
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }
}
