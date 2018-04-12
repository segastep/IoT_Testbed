Here is some useful cluster information.

1. Flink
 -Once the setup script is finished copy the service file to the master node.
 2. Zookeeper
 - Pass the local ip's as script parameters, once the setup is done on each machine edit zoo.conf (/ext/Zookeeper/conf/)
 for each machine update the server.X ( where x is the myid of the machine) to 0.0.0.0
 e.g server.1 on machine 1 becomes 0.0.0.0:port:port
     server.2 on machine 2 becomes 0.0.0.0:port:port - server.1 and server.3 point to their local IP's


