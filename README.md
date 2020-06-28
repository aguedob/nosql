



# NoSQL

Máster en Big Data Analytics. Curso 2019/2020



[TOC]

Autores:

- Enrique Puig Nouselles ()

- José Ángel Soler Amo ()
- Andrés Guerrero Doblado (andres@meigal.com)





# Introducción

## Objetivos

El objetivo de estre trabajo es ilustrar las ventajas e inconvenientes de los sistemas de bases de datos relacionales frente a sistemas NoSQL o libres de esquema.



## El problema

La idea de la cual se parte es un problema real. Uno de los miembros del equipo se dedica a la monitorización de infraestructuras TI, y hace uso de una herramienta comercial que almacena información en una base de datos relacional. La aplicación sufre de un problema endémico conocido: hay una penalización bastante alta en el rendimiento de ciertas operaciones cuando el número de items monitorizados aumenta.



A continuación se describen las entidades principales:

- **Monitor**. Define un patrón de monitorización. Ejemplo: Monitorización de espacio para puntos de montaje en sistemas RHEL7.

- **PerformanceRule. **Define un patrón de recolección de datos de rendimiento. Ejemplo: Recolección del porcentaje de CPU utilizado en sistemas Windows 2019.

- **ConfigurationItem (en adelante, CI)**. Representa cada uno de los elementos monitorizados en el sistema. Cada uno de ellos pertenece a una clase diferente y pueden poseer ciertos atributos. Cada CI tiene las siguientes características:

  - Poseen atributos, que son pares de clave-valor que pueden utilizarse para diversas tareas, como agrupar los CIs o crear vistas de usuario.

  - Los CIs pueden instanciar entidades de tipo Monitor y tipo Performance_Rule. 

  - - Las instancias de tipo Monitor proporcionarán un estado de salud y almacenarán los cambios de estado que hayan sufrido a lo largo del tiempo, de modo que podremos no solo consultar el estado de salud de los monitores asociados a un CI, sino también consultar el histórico de cambios de estado.
    - Las instancias de tipo Performance_Rule representan una métrica a tomar de un determinado CI. Cada CI puede instanciar varias Performance_Rule y cada una de estas instancias almacenará el histórico de una métrica de rendimiento determinada, como por ejemplo el espacio ocupado en un disco o la temperatura ambiente en una sala.



Esquema de relacional:

![image-20200628080744698](/Users/guerrero/Library/Application Support/typora-user-images/image-20200628080744698.png)

## Autoría del trabajo

### Autores

- Enrique Puig Nouselles ()

- José Ángel Soler Amo ()
- Andrés Guerrero Doblado (andres@meigal.com)

#### Reparto de tareas

- Fase de análisis del problema, implementación de la base de datos relacional, generación de datos y documentación:
  - Todos
- Implementación del sistema NoSQL con Cassandra:
  - Enrique Puig
- Implementación del sistema NoSQL con mongoDB:
  - Andrés Guerrero
- Implementación del sistema NoSQL con Neo4J:
  - José Ángel Soler Amo



# Implementaciones

## Cassandra



## MongoDB



### Infraestructura del cluster mongo

Comenzamos describiendo la arquitectura del cluster de mongo implementada.

- 3 nodos de réplica:
  - **mongos1n1**, **mongos1n2** y **mongos1n3**
- 3 config servers: 
  - **mongocfg1, mongocfg2 y mongocfg3**
- 2 servidores mongos para rutar las peticiones de clientes:
  - **mongos1 y mongos2**



![Image title](https://image.ibb.co/ke9P2F/Screen_Shot_2017_08_02_at_13_45_21.png)





## 

Aunque en un sistema de producción nunca se deberían instalar todos los servicios en el mismo nodo, con el fin de simplificar la instalación para el propósito de la práctica, se han utilizado contenedores Docker siguiendo la guía referenciada en este sitio web: https://dzone.com/articles/composing-a-sharded-mongodb-on-docker. 

Este es el fichero docker-compose.yaml utilizado:

```yaml
version: '2'
services:
    mongorsn1:
        container_name: mongors1n1
        image: mongo
        command: mongod --shardsvr --replSet mongors1 --dbpath /data/db --port 27017
        ports:
        - 27017:27017
        expose:
        - "27017"
        environment:
            TERM: xterm
        volumes:
        - ~/nosql/mongo_cluster/localtime:/etc/localtime:ro
        - ~/nosql/mongo_cluster/data1:/data/db
    mongors1n2:
        container_name: mongors1n2
        image: mongo
        command: mongod --shardsvr --replSet mongors1 --dbpath /data/db --port 27017
        ports:
        - 27027:27017
        expose:
        - "27017"
        environment:
            TERM: xterm
        volumes:  
        - ~/nosql/mongo_cluster/localtime:/etc/localtime:ro
        - ~/nosql/mongo_cluster/data2:/data/db
    mongors1n3:
        container_name: mongors1n3
        image: mongo
        command: mongod --shardsvr --replSet mongors1 --dbpath /data/db --port 27017
        ports:
        - 27037:27017
        expose:
        - "27017"
        environment:
            TERM: xterm
        volumes:
        - ~/nosql/mongo_cluster/localtime:/etc/localtime:ro
        - ~/nosql/mongo_cluster/data3:/data/db
    mongocfg1:
        container_name: mongocfg1
        image: mongo
        command: mongod --configsvr --replSet mongors1conf --dbpath /data/db --port 27017
        environment:
            TERM: xterm
        expose:
            - "27017"
        volumes:
            - ~/nosql/mongo_cluster/localtime:/etc/localtime:ro
            - ~/nosql/mongo_cluster/config1:/data/db
    mongocfg2:
        container_name: mongocfg2
        image: mongo
        command: mongod --configsvr --replSet mongors1conf --dbpath /data/db --port 27017
        environment:
            TERM: xterm
        expose:
            - "27017"
        volumes:
            - ~/nosql/mongo_cluster/localtime:/etc/localtime:ro
            - ~/nosql/mongo_cluster/config2:/data/db
    mongocfg3:
        container_name: mongocfg3
        image: mongo
        command: mongod --configsvr --replSet mongors1conf --dbpath /data/db --port 27017
        environment:
            TERM: xterm
        expose:
            - "27017"
        volumes:
            - ~/nosql/mongo_cluster/localtime:/etc/localtime:ro
            - ~/nosql/mongo_cluster/config3:/data/db
    mongos1:
        container_name: mongos1
        image: mongo
        depends_on:
        - mongocfg1
        - mongocfg2
        command: mongos --configdb mongors1conf/mongocfg1:27017,mongocfg2:27017,mongocfg3:27017 --port 27017
        ports:
        - 27019:27017
        expose:
        - "27017"
        volumes:
        - ~/nosql/mongo_cluster/localtime:/etc/localtime:ro
    mongos2:
        container_name: mongos2
        image: mongo
        depends_on:
        - mongocfg1
        - mongocfg2
        command: mongos --configdb mongors1conf/mongocfg1:27017,mongocfg2:27017,mongocfg3:27017 --port 27017
        ports:
        - 27020:27017
        expose:
        - "27017"
        volumes:
        - ~/nosql/mongo_cluster/localtime:/etc/localtime:ro
```



Tras ejecutar `docker compose up`, podemos comprobar que se han levantado todos los nodos que conforman la arquitectura:

```bash
ONTAINER ID     IMAGE       COMMAND                  CREATED         STATUS          PORTS                      NAMES
082dd7e0e899    mongo       "docker-entrypoint.s…"   37 minutes ago  Up 15 minutes   0.0.0.0:27020->27017/tcp   mongos2
6ce9bec6177d    mongo       "docker-entrypoint.s…"   37 minutes ago  Up 15 minutes   0.0.0.0:27019->27017/tcp   mongos1
1a00b0558347    mongo       "docker-entrypoint.s…"   37 minutes ago  Up 15 minutes   0.0.0.0:27017->27017/tcp   mongors1n1
86b1e7786e9a    mongo       "docker-entrypoint.s…"   37 minutes ago  Up 15 minutes   27017/tcp                  mongocfg2
3d9c7b2ced01    mongo       "docker-entrypoint.s…"   37 minutes ago  Up 15 minutes   0.0.0.0:27037->27017/tcp   mongors1n3
840d45fb27eb    mongo       "docker-entrypoint.s…"   37 minutes ago  Up 15 minutes   27017/tcp                  mongocfg1
f6f2c8c7351a    mongo       "docker-entrypoint.s…"   37 minutes ago  Up 15 minutes   27017/tcp                  mongocfg3
68bd894e1157    mongo       "docker-entrypoint.s…"   37 minutes ago  Up 15 minutes   0.0.0.0:27027->27017/tcp   mongors1n2
```



Start mongo cluster:

docker start docker ps  -a  | grep mongo | cut -f1 -d " "

Stop mongo cluster:

docker stop ``docker ps  -a  | grep mongo | cut -f1 -d " "





#### Importación de datos

Actualmente tenemos los datos en una base de datos relacional, siguiendo el esquema 