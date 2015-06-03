library server;

import 'package:redstone/server.dart' as app;

@app.Route("/usages/:declarationId", methods: const[app.GET])
helloWorld(int declarationId) {
  return "$declarationId";
}

void main() {
  app.setupConsoleLog();
  app.start();
}