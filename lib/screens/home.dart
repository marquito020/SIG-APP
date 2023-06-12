import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:sig_grupL/components/google_maps.dart';
import 'package:sig_grupL/controllers/apiController.dart';
import 'package:sig_grupL/utils/datosJSON.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';

import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;

import '../utils/maps_style.dart';

class CustomSearchDelegate extends SearchDelegate<String> {
  List<String> datosPostgrados = [];

  List<String> getMatchedResults(String query) {
    return datosPostgrados
        .where((item) => item.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  final List<dynamic>? data;

  CustomSearchDelegate({this.data}) {
    if (data != null) {
      datosPostgrados =
          data!.map((item) => item['description'] as String).toList();
    }
  }

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        onPressed: () {
          query = '';
        },
        icon: const Icon(Icons.clear),
      )
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      onPressed: () {
        Navigator.pop(context);
      },
      icon: const Icon(Icons.arrow_back),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    final matchQuery = getMatchedResults(query);
    return Search(
      allData:
          datosPostgrados.where((item) => matchQuery.contains(item)).toList(),
      onItemSelected: (item) {
        final data = jsonData.firstWhere(
          (element) => element['description'] == item,
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

        if (kDebugMode) {
          print(position);
        }

        close(context, item);
        final homeState = context.findAncestorStateOfType<_HomeState>();
        homeState?.addMarker(position);
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final matchQuery = getMatchedResults(query);
    if (matchQuery.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    return Search(
      allData:
          datosPostgrados.where((item) => matchQuery.contains(item)).toList(),
      onItemSelected: (item) {
        query = item;
        showResults(context);
      },
    );
  }
}

class Search extends StatelessWidget {
  final List<String> allData;
  final ValueChanged<String> onItemSelected;

  const Search({Key? key, required this.allData, required this.onItemSelected})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: allData.length,
      itemBuilder: (context, index) {
        final item = allData[index];
        return ListTile(
          title: Text(item),
          onTap: () {
            onItemSelected(item);
          },
        );
      },
    );
  }
}

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

    if (miUbicacion) {
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
      mostrarMarcador = false;
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
      mostrarMarcador = false;
      setState(() {
        markers.add(newMarker);
        if (dosPuntos) createPolylines(position);
      });
    }
  }

  void createPolylines(LatLng position) async {
    PolylinePoints polylinePoints = PolylinePoints();

    PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
      "AIzaSyB7NyPjOpe124gfoeWrg_8Knwv-rcvslT8",
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

    if (miUbicacion) {
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
    }

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

  @override
  void initState() {
    _init();
    getCurrentLocation();
    ApiController().leerJSON().then((data) {
      setState(() {
        jsonData = data;
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Buscar Destino"),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () async {
              /* En caso de que no carguen o no encuentre los datos */
              if (jsonData.isEmpty) {
                return;
              }
              final String? selected = await showSearch<String>(
                context: context,
                delegate: CustomSearchDelegate(data: jsonData),
              );
              if (selected != null) {
                if (kDebugMode) {
                  print(jsonData);
                }
                final data = jsonData.firstWhere(
                  (element) => element['description'] == selected,
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
                if (markers.isNotEmpty) {
                  if (kDebugMode) {
                    print("Hay marcadores");
                  }
                  dosPuntos = true;
                  miUbicacion = false;
                  description = data['description'].toString();
                  group = data['group'].toString();
                  initials = data['initials'].toString();
                  addMarker(position);
                  /* ComponentsGoogleMaps().addMarker(
                      position,
                      bandera,
                      miUbicacion,
                      dosPuntos,
                      mostrarMarcador,
                      markers,
                      currentLocation!,
                      _mapController,
                      polylineCoordinates,
                      inicioLatitude,
                      inicioLongitude,
                      totalDistance);
                  setState(() {
                    ComponentsGoogleMaps().createPolylines(
                        position,
                        inicioLatitude,
                        inicioLongitude,
                        polylineCoordinates,
                        bandera,
                        miUbicacion,
                        currentLocation!,
                        _mapController,
                        totalDistance);
                  }); */
                } else {
                  AlertDialog(
                    title: const Text('Error'),
                    content:
                        const Text('No se ha seleccionado un punto de inicio.'),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: const Text('Aceptar'),
                      ),
                    ],
                  );
                }
              }
            },
            icon: const Icon(Icons.search),
          )
        ],
      ),
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
                /* _initialPosition, */
                onMapCreated: (GoogleMapController controller) {
                  _completer.complete(controller);
                },
                /* myLocationEnabled: true, */
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                markers: markers,
                polylines: {
                  Polyline(
                    polylineId: const PolylineId('polyLine'),
                    color: Colors.red,
                    points: polylineCoordinates,
                    width: 5,
                  ),
                },
                /* onTap: (LatLng position) {
                if (markers.isEmpty) {
                  addMarker(position);
                } else {
                  removeMarker(markers.first.markerId);
                }
              }, */
              ),
            ),
          if (dosPuntos)
            Container(
                alignment: Alignment.bottomCenter,
                child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      width: double.infinity,
                      height: 85,
                      color: Colors.white,
                      child: Column(
                        children: [
                          SizedBox(
                            child: Text("Distancia: $totalDistance km",
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black)),
                          ),
                          SizedBox(
                            child: Text("Grupo: $group",
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black)),
                          ),
                          SizedBox(
                            child: Text("Iniciales: $initials",
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black)),
                          ),
                          SizedBox(
                            child: Text("Descripcion: $description",
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black)),
                          ),
                        ],
                      ),
                    ))),
          if (finMarker == false)
            Container(
              margin: const EdgeInsets.only(top: 10),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                    width: double.infinity,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: SizedBox(
                      child: ButtonBar(
                        alignment: MainAxisAlignment.center,
                        children: [
                          /* Marcar Inicio */
                          ElevatedButton(
                            onPressed: () {
                              /* Ventana */
                              showDialog(
                                context: context,
                                builder: (BuildContext context) {
                                  return AlertDialog(
                                    title: const Text('Inicio'),
                                    content: const Text(
                                        '¿Desea marcar su ubicación actual como inicio?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                        },
                                        child: const Text('Cancelar'),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          Navigator.of(context).pop();
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
                                        },
                                        child: const Text('Aceptar'),
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text('Inicio desde mi ubicación'),
                          ),
                        ],
                      ),
                    )),
              ),
            ),
          if (mostrarMarcador)
            Center(
              heightFactor: 11.5,
              child: Opacity(
                opacity: markers.isEmpty ? 1.0 : 0.0,
                child: Image.asset(
                  'assets/icons/mark_start.png',
                  width: 50,
                  height: 50,
                ),
              ),
            ),
          Container(
            margin: const EdgeInsets.only(top: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FloatingActionButton(
                  heroTag: 'add_location',
                  onPressed: () {
                    _completer.future.then((GoogleMapController controller) {
                      controller.getVisibleRegion().then((LatLngBounds bounds) {
                        final LatLng centerLatLng = LatLng(
                          (bounds.northeast.latitude +
                                  bounds.southwest.latitude) /
                              2,
                          (bounds.northeast.longitude +
                                  bounds.southwest.longitude) /
                              2,
                        );
                        if (markers.isEmpty) {
                          inicioLatitude = centerLatLng.latitude;
                          inicioLongitude = centerLatLng.longitude;
                          dosPuntos = false;
                          mostrarMarcador = false;
                          bandera = false;
                          /* addMarker(centerLatLng); */
                          ComponentsGoogleMaps().addMarker(
                              centerLatLng,
                              bandera,
                              miUbicacion,
                              dosPuntos,
                              mostrarMarcador,
                              markers,
                              currentLocation!,
                              _mapController,
                              polylineCoordinates,
                              inicioLatitude,
                              inicioLongitude,
                              totalDistance);
                          finMarker = true;
                          setState(() {});
                        } else {
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
                        }
                      });
                    });
                  },
                  child: markers.isEmpty
                      ? const Icon(Icons.add_location)
                      : const Icon(Icons.delete),
                ),
                const SizedBox(width: 10),
                FloatingActionButton(
                  heroTag: 'gps_fixed',
                  onPressed: () async {
                    final GoogleMapController controller = await _mapController;
                    controller.animateCamera(
                      CameraUpdate.newCameraPosition(
                        CameraPosition(
                          target: LatLng(
                            currentLocation!.latitude!,
                            currentLocation!.longitude!,
                          ),
                          zoom: 18,
                        ),
                      ),
                    );
                  },
                  child: const Icon(Icons.gps_fixed),
                ),
                const SizedBox(width: 10),
                FloatingActionButton(
                  heroTag: 'location_searching',
                  onPressed: () async {
                    final GoogleMapController controller = await _mapController;
                    controller.animateCamera(
                      CameraUpdate.newCameraPosition(
                        CameraPosition(
                          target: LatLng(
                            currentLocation!.latitude!,
                            currentLocation!.longitude!,
                          ),
                          zoom: 13.5,
                        ),
                      ),
                    );
                  },
                  child: const Icon(Icons.location_searching),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
