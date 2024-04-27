import 'dart:developer';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:geobin/collections.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class HomePage extends StatefulWidget {
  HomePage({super.key});
  List<Marker> markers = [];
  Map<String, Map<String, dynamic>> data = {};
  late LatLng userLocation;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Future<bool> signOutFromGoogle() async {
    try {
      await FirebaseAuth.instance.signOut();
      return true;
    } on Exception catch (_) {
      return false;
    }
  }

  void listenForChanges() {
    final listener = FBCollections.geotags.snapshots().listen((event) async {
      setState(() {});
    });
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
      widget.userLocation = await _determinePosition();
      QuerySnapshot data = await FBCollections.geotags.get();
      //log(data.size.toString());
      for (DocumentSnapshot doc in data.docs) {
        Map<String, dynamic> docData = doc.data() as Map<String, dynamic>;
        widget.data[doc.id] = (docData);
        //log(data["latitude"].runtimeType.toString());
        try {
          widget.markers.add(Marker(
            point: LatLng(docData['latitude'] ?? double.parse("0.0"),
                docData['longitude'] ?? double.parse("0.0")),
            child: Icon(
              Icons.location_on,
              color: Colors.red,
            ),
          ));
        } catch (e) {
          log("Nigga yaha hai error ${e}");
        }
      }
      // widget.markers.forEach((element) {
      //   log(element.point.toString());
      // });
      setState(() {});
      listenForChanges();
    });
  }

  Future<LatLng> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled don't continue
      // accessing the position and request users of the
      // App to enable the location services.
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Permissions are denied, next time you could try
        // requesting permissions again (this is also where
        // Android's shouldShowRequestPermissionRationale
        // returned true. According to Android guidelines
        // your App should show an explanatory UI now.
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Permissions are denied forever, handle appropriately.
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }
    Position position = await Geolocator.getCurrentPosition();
    // When we reach here, permissions are granted and we can
    // continue accessing the position of the device.
    return LatLng(position.latitude, position.longitude);
  }

  void setParentState() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    const styleUrl =
        "https://tiles.stadiamaps.com/tiles/alidade_smooth_dark/{z}/{x}/{y}{r}.png";
    const apiKey = "a1e9793d-bed4-4986-949c-24f3abf9e654";
    return Scaffold(
      appBar: AppBar(
        title: Text("Nearby Trash Heaps"),
      ),
      body: widget.markers.isEmpty
          ? Center(
              child: CircularProgressIndicator(),
            )
          : FlutterMap(
              options: MapOptions(
                  initialCenter: widget.userLocation,
                  // center: LatLng(59.438484, 24.742595),
                  initialZoom: 14,
                  keepAlive: true),
              children: [
                TileLayer(
                  urlTemplate: "$styleUrl?api_key={api_key}",
                  additionalOptions: {"api_key": apiKey},
                  maxZoom: 20,
                  maxNativeZoom: 20,
                ),
                CurrentLocationLayer(
                    alignPositionOnUpdate: AlignOnUpdate.always,
                    alignDirectionOnUpdate: AlignOnUpdate.always,
                    style: LocationMarkerStyle(
                      marker: const DefaultLocationMarker(
                        child: Icon(
                          Icons.navigation,
                          color: Colors.white,
                        ),
                      ),
                      markerSize: const Size(30, 30),
                      markerDirection: MarkerDirection.heading,
                    )),
                MarkerClusterLayerWidget(
                  options: MarkerClusterLayerOptions(
                    onMarkerTap: (marker) {
                      Map<String, dynamic> data = widget.data.values
                          .where((element) =>
                              element['latitude'] == marker.point.latitude &&
                              element['longitude'] == marker.point.longitude)
                          .first;
                      String docID = widget.data.keys
                          .where((element) => widget.data[element] == data)
                          .first;
                      String imageUrl = data["pic_url"];
                      // log(data["pic_url"]);
                      showDialog(
                          context: context,
                          builder: (BuildContext context) => Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 500, vertical: 200),
                                child: Container(
                                  color: Colors.amber,
                                  child: Center(
                                      child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      CachedNetworkImage(
                                        imageUrl: imageUrl,
                                        fit: BoxFit.contain,
                                        placeholder: (context, url) => Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 10,
                                      ),
                                      ElevatedButton(
                                          onPressed: () async {
                                            String uid = data["uid"];
                                            DocumentSnapshot userData =
                                                await FBCollections.users
                                                    .doc(uid)
                                                    .get();
                                            Map<String, dynamic> userDataMap =
                                                userData.data()
                                                    as Map<String, dynamic>;
                                            await FBCollections.geotags
                                                .doc(docID)
                                                .delete();
                                            userDataMap['isReported'] == false
                                                ? await FBCollections.users
                                                    .doc(uid)
                                                    .update(
                                                        {"isReported": true})
                                                : await FBCollections.users
                                                    .doc(uid)
                                                    .update({"isBanned": true});
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(SnackBar(
                                                    content: Text(
                                                        "Reported Successfully")));
                                            Navigator.pop(context);
                                            setParentState();
                                          },
                                          child: Text("Report")),
                                    ],
                                  )),
                                ),
                              ));
                      //log("On Pressed");
                    },
                    maxClusterRadius: 45,
                    size: const Size(40, 40),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.all(50),
                    maxZoom: 15,
                    markers: widget.markers,
                    builder: (context, markers) {
                      return Container(
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            color: Colors.blue),
                        child: Center(
                          child: Text(
                            markers.length.toString(),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
