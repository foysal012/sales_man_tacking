import 'package:flutter/material.dart';
import 'model/location_data_model.dart';
import 'services/database_services.dart';

class LocationHistoryPage extends StatefulWidget {
  const LocationHistoryPage({super.key});

  @override
  State<LocationHistoryPage> createState() => _LocationHistoryPageState();
}

class _LocationHistoryPageState extends State<LocationHistoryPage> {

  List<LocationModel> _historyList = [];

  Future<void> loadLocation() async{
    final history = await DatabaseServices.instance.getAllLocations();
    setState(() {
      _historyList = history.map<LocationModel>((e) => LocationModel.fromMap(e)).toList();
    });
  }

  @override
  void initState() {
    super.initState();
    loadLocation();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Location History'),
        backgroundColor: Colors.blueAccent,
        actions: [
          IconButton(onPressed: () => DatabaseServices.instance.clearLocations(), icon: Icon(Icons.delete))
        ],
      ),

      body: Container(
        child: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              _historyList.isEmpty?
                  Text('No data found.'):FutureBuilder(
                  future: loadLocation(),
                  builder: (context, snapshot) {
                    if(snapshot.hasError){
                      return Text('Something went wrong');
                    } else {
                      return ListView.builder(
                        physics: NeverScrollableScrollPhysics(),
                        itemCount: _historyList.length,
                          shrinkWrap: true,
                          itemBuilder: (context, index) {
                          final history = _historyList[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 15.0),
                              child: Card(
                                elevation: 2,
                                margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 0),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.all(10),
                                  title: Text(
                                      'Lat: ${history.latitude}, Long: ${history.longitude}',
                                      style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500
                                      )
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Accuracy: ${history.accuracy} m',
                                        style: const TextStyle(
                                            fontSize: 14,
                                            color: Colors.black54
                                        ),
                                      ),
                                      Text(
                                        'Timestamp: ${history.timestamp
                                            .toString()
                                            .substring(0, 19)}',
                                        style: const TextStyle(
                                            fontSize: 14,
                                            color: Colors.black54
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                      );
                    }
                  },
              )
            ],
          ),
        ),
      ),
    );
  }
}
