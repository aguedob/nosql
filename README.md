





# NoSQL

Máster en Big Data Analytics. Curso 2019/2020

[TOC]

# Introducción

## Objetivos

El objetivo de este trabajo es ilustrar las ventajas e inconvenientes de los sistemas de bases de datos relacionales frente a sistemas NoSQL o libres de esquema.

## Autoría del trabajo

### Autores

- Enrique Puig Nouselles ([e.puig@outlook.es](e.puig@outlook.es))

- José Ángel Soler Amo ([joseangelsoleramo@hotmail.com](joseangelsoleramo@hotmail.com))

- Andrés Guerrero Doblado (andres@meigal.com)

  
### Reparto de tareas

- Fase de análisis del problema, implementación de la base de datos relacional, generación de datos y documentación:
  - Todos
- Implementación del sistema NoSQL con Cassandra:
  - Enrique Puig
- Implementación del sistema NoSQL con mongoDB:
  - Andrés Guerrero
- Implementación del sistema NoSQL con Neo4J:
  - José Ángel Soler Amo

## Caso de estudio

La idea de la cual se parte es un problema real. Uno de los miembros del equipo se dedica a la monitorización de infraestructuras TI, y hace uso de una herramienta comercial que almacena información en una base de datos relacional. La aplicación sufre de un problema endémico conocido: hay una penalización bastante alta en el rendimiento de ciertas operaciones cuando el número de items monitorizados aumenta.

A continuación se describen las entidades principales:

- **Monitor**. Define un patrón de monitorización. Ejemplo: Monitorización de espacio para puntos de montaje en sistemas RHEL7.

- **PerformanceRule. **Define un patrón de recolección de datos de rendimiento. Ejemplo: Recolección del porcentaje de CPU utilizado en sistemas Windows 2019.

- **ConfigurationItem (en adelante, CI)**. Representa cada uno de los elementos monitorizados en el sistema. Cada uno de ellos pertenece a una clase diferente y pueden poseer ciertos atributos. Cada CI tiene las siguientes características:

  - Poseen atributos, que son pares de clave-valor que pueden utilizarse para diversas tareas, como agrupar los CIs o crear vistas de usuario.

  - Los CIs pueden instanciar entidades de tipo Monitor y tipo Performance_Rule. 

  - - Las instancias de tipo Monitor proporcionarán un estado de salud y almacenarán los cambios de estado que hayan sufrido a lo largo del tiempo, de modo que podremos no solo consultar el estado de salud de los monitores asociados a un CI, sino también consultar el histórico de cambios de estado.
    - Las instancias de tipo Performance_Rule representan una métrica a tomar de un determinado CI. Cada CI puede instanciar varias Performance_Rule y cada una de estas instancias almacenará el histórico de una métrica de rendimiento determinada, como por ejemplo el espacio ocupado en un disco o la temperatura ambiente en una sala.



Esquema relacional:

![esquema](./images/esquema.png)

### Organización de la información

A la hora de diseñar la estructura de los documentos donde almacenaremos la información, es imprescindible analizar cuáles serán las consultas que más se ejecutarán sobre los datos, con el fin de optimizarlas. El sistema de monitorización que se utiliza como ejemplo, existen dos roles principales de uso, que determinan claramente el diseño.

**Rol de operador**: El operador de la infraestructura de TI tiene como principal tarea comprobar de forma periódica la consola de monitorización, donde aparece en primera instancia una vista de las alertas que se encuentra en estado "New". 

**Rol de técnicos de nivel 2 o nivel 3:** Los técnicos de nivel 2 y nivel 3 tan sólo intervendrán cuando el operador les avise que existe un incidente en un CI determinado que no han podido solventar. Dichos técnicos acudirán al sistema de monitorización para obtener más información sobre el estado de salud del CI afectado. Para ello, revisarán qué monitores se encuentran en un estado no saludable, desde cuándo así los últimos datos de rendimiento tomados por el sistema, como por ejemplo el consumo de CPU o memoria.

Una vez identificados los casos de uno más comunes, identificamos claramente que las entidades Configuration_Item y Alert deben ser las que se utilicen para particionar la información.



# Consultas

Con el fin de comprobar la eficiencia del sistema una vez migrado a una arquitectura libre de esquema, hemos planteado el diseño de la siguientes consultas:

1. **Listado de alertas pendientes (prioridad == New)**: Tal y como mencionamos en el análisis previo, la consulta de alertas pendientes es uno de los principales casos de uso del sistema de monitorización. La vista de alertas pendientes se refrescará con una periodicidad alta en las consolas de los operadores. La información mínima a mostrar por alerta consistirá en el nombre de la alerta, la severidad, el item afectado y la fecha en la que se registra el incidente.

2. **Cambios de estado de un monitor específico en un servidor**. Una vez se identifica el CI afectado, los técnicos estudiarán los posibles cambios de estado del monitor afectado, con el fin de detectar si es un problema de duración determinada puntual o si por el contrario es recurrente.

   Necesitarán conocer: el nombre del monitor y el CI afectado, así como los cambios de estado registrados junto con la fecha.

3. **Obtención de los datos de rendimiento recolectados para una regla de recolección específica en un servidor.** Además de los cambios de estado, la información de ciertos contadores de rendimiento, pueden proporcionar a los técnicos información muy relevante a la hora de identificar la raíz de un problema. Para cada contador, se necesitará devolver una lista con los valores y en la fecha que se registraron.

# Implementaciones

## Cassandra

### Infraestructura del clúster cassandra

La arquitectura utilizada para la implementación de la práctica es la misma que se utilizo durante las clases en el entorno del DSIC con las 6 maquinas virtuales proporcionadas.

- Topología: Un único datacenter

- Clúster de 6 nodos
  
  - NOSQL-025-1 , NOSQL-025-2, NOSQL-025-3, NOSQL-025-4, NOSQL-025-5 y NOSQL-025-6
- Nodos Seed
  
  - NOSQL-025-1
  
    

![cassandra-architecture](images/cassandra-architecture.png)


En esta arquitectura se ha dejado solamente un nodo seed. Los nodos seed tienen un rol especial dentro del cluster, y es que se encargan de la sincronización de los nuevos nodos que entran a formar parte del cluster o incluso de nodos que ya formaban parte pero se han apartado bien por mantenimiento o bien por errores y desincronización. Idealmente deberia haber mas de uno, pero para el caso practico que nos atañe con uno será suficiente.

#### Instalación y configuración del cluster

Tal y como se ha comentado anteriormente, para la implementación del modelo en casandra se ha utilizado el cluster que se instaló y configuró en clase. A continuación se detallan los pasos seguidos:

1. Instalación de cassandra

   - Se ha instalado cassandra mediante los paquetes RPM que ya habian sido descargados previamente.

     ```bash
     rpm -ivf /root/Software/cassandra/dsc22/*.rpm
     ```

   - Se han borrado las carpetas por defecto

     ```bash
     rm -rf /var/lib/cassandra/*
     ```

   - Asignación de permisos al usuario cassandra a la carpeta home de cassandra

     ```bash
     chown cassandra.cassandra /var/lib/cassandra
     ```

2. Configuración cassanda (cassandar.yml) cluster 1 nodo

   Para la configuración del cluster de cassandra se configura primero un nodo y despues se replica al resto de nodos. Para ello se han realizado los siguientes cambios en el fichero `/etc/cassandra/conf/cassandra.yaml`

   - cluster_name: **nosql-025**
   - data_file_directories: **`/var/lib/cassandra/cluster_nosql-025/data`**
   - commitlog_directory: **`/var/lib/cassandra/cluster_nosql-025/commitlog`**
   - saved_caches_directory: **`/var/lib/cassandra/cluster_nosql-025/saved_caches`**
   - commitlog_total_space_in_mb: **1024**

3. Arrancar el servicio de cassandra

   - `service cassandra start`

4. Despliegue del cluster en el resto de nodos

   Una vez se ha configurado el nodo 1, se extiende esta configuración al resto de nodos. Para ello se ha implementado un script en bash que automiza este trabajo. 

   ```bash
   #!/bin/bash
   
   if [[ $# -eq 0 ]]; then
           echo "Missing arguments. no action has been done!"
           exit 2
   fi
   
   for i in $@
   do
           echo $i
   
           #install cassandra software
           ssh root@$i rpm -ivf /root/Software/cassandra/dsc22/*.rpm
   
           #delete default folders
           ssh root@$i rm -rf /var/lib/cassandra/*
   
           #assign permissions to cassandra folder
           ssh root@$i chown cassandra.cassandra /var/lib/cassandra
   
           #copy config files from node 1 to others
           scp /etc/cassandra/conf/cassandra.yaml root@$i:/etc/cassandra/conf/
           scp /etc/cassandra/conf/cassandra-env.sh root@$i:/etc/cassandra/conf/
   
           #start cassandra
           ssh root@$i service cassandra start
   
   done
   ```

5. Una vez instalado e iniciado el servicio de cassandra en todos los nodos del cluster, podemos ver el estado del mismo mediante la utilidad **nodetool**. Se ejecuta el comando y se observan los 6 nodos levantados con el servicio ejecutándose y en estado normal.

   `nodetool status`

   ![cassandra-nodetool](images/cassandra-nodetool.png)

### Modelo de base de datos

A partir del modelo entidad-relacion del sistema elegido, se ha credo un keyspace en el cluster de cassandra y se ha modelado una solución para el mismo.

#### Keyspace

Para esta practica y puesto que solamente estamos usando un único data center, se ha creado el keyspace **sysmonitor** con SimpleStrategy y un factor de replicación de 3 nodos que supone el 50% de los nodos del clúster.

```cassandra
CREATE KEYSPACE sysmonitor 
WITH replication = {'class': 'SimpleStrategy', 'replication_factor': '3'}
```



#### Modelo

Una vez creado el keyspace, comenzamos con la fase de modelado. En este caso en particular, y en base a las consultas que se quieren poder resolver en este caso de uso en concreto, hemos definido varios tipos de datos personalizados, Mapas de clave valor y únicamente dos tablas, una de alertas y otra de configuration items.

El principal motivo de esta decisión es debido al uso y a las consultas que necesita el sistema. Este tipo de soluciones de monitorización suelen ser utilizadas por 2 roles:
- **Operador**: Se encarga de ver las alertas abiertas y asígnarlas a los tecnicos a traves de incidencias.
- **Tecnico**: Se encarga de revisar las incidencias y revisar los configuration items relacionados.

En base a estos requisitos, pese a que las alertas estan relacionadas con monitores que estasn asociados a configuration items, hemos preferido crear dos tablas y redundar ciertos datos para satisfacer las consultas clave del sistema de monitorizacion.

Se han definido los siguientes tipos de datos propios:

```cassandra
CREATE TYPE sysmonitor.alert (
    alert_instance_id int,
    severity text,
    priority text,
    state_change_date timestamp,
    alert_state_name text
);

CREATE TYPE sysmonitor.monitor_state (
    monitor_state_id int,
    state_change_date timestamp,
    health_state text
);

CREATE TYPE sysmonitor.monitor (
    monitor_instance_id int,
    name text,
    description text,
    alert_name text,
    alert_description text,
    monitor_parameters frozen<map<text, int>>,
    monitor_states frozen<list<frozen<monitor_state>>>
);

CREATE TYPE sysmonitor.performance_data (
    perf_rule_name text,
    perf_rule_desc text,
    collected_date timestamp,
    value int
);
```

Una vez creados los tipos, se crean las dos tablas principales del sistema:

```cassandra
CREATE TABLE sysmonitor.configuration_item (
    ci_id int,
    attributes map<text, text>,
    monitors list<frozen<monitor>>,
    name text,
    performance_counters list<frozen<performance_data>>,
  	primary key (name,ci_id)
);

CREATE TABLE sysmonitor.alert (
    alert_state_name text,
    monitor_instance_id int,
    ci_id int,
    alert_instance_id int,
    alert_name text,
    ci_name text,
    monitor_id int,
    priority text,
    severity text,
    state_change_date timestamp,
    PRIMARY KEY (alert_state_name, monitor_instance_id, ci_id,state_change_date);
```

- Las tablas estan formadas por tipos base y tambien por colecciones de tipos complejos.
- Las claves de partición se han elegido para la correcta distribucion de datos en el cluster y tambien para poder filtrar queries en base a los campos mas criticos.

### Carga de datos

En esta fase se estudian los diferentes métodos de carga de datos:

- ##### Generación de scripts CQL a partir del sistema relacional

  Una primera aproximación para la carga de datos en cassandra ha sido usar los comandos conocidos de TSQL en SQL Server (base de datos original) para generar los scripts de inserción de datos en cassandra con la sintaxis esperada. Por ejemplo, para insertar las alertas en la tabla de alertas de cassandra hemos usado el siguiente script de TSQL:

  ```mssql
  select
      '
      INSERT INTO sysmonitor.alert 
      (
          ci_id,monitor_id,
          monitor_instance_id,
          alert_instance_id,
          severity,
          priority,
          state_change_date,
          alert_state_name,
          ci_name,
          alert_name
      ) 
      values (
          '+cast(mins.ci_id as varchar(100))+',
          '+cast(mins.monitor_id as varchar(100))+',
          '+cast(ai.mon_isntance_id as varchar(100))+',
          '+cast(ai.alert_instance_id as varchar(100))+',
          '''+severity+''',
          '''+priority+''',
          '''+convert(varchar(20),ai.state_change_date,120)+''',
          '''+ast.state_name+''',
          '''+ci.name+''',
          '''+m.alert_name+'''
      );
      '
  from Alert_Instance as ai
  inner join Alert_State as ast
      on ast.state_id=ai.alert_State_id
  inner join Monitor_Instance as mins
      on mins.mon_isntance_id=ai.mon_isntance_id
  inner join Monitor as m
      on m.monitor_id=mins.monitor_id
  inner JOIN ConfigurationItem as ci
      on ci.ci_id=mins.ci_id
  
  ```

  Esta consulta nos genera comandos insert como el siguiente:

  ```mssql
  
      INSERT INTO sysmonitor.alert 
      (
          ci_id,monitor_id,
          monitor_instance_id,
          alert_instance_id,
          severity,
          priority,
          state_change_date,
          alert_state_name,
          ci_name,
          alert_name
      ) 
      values (
          1,
          31,
          1,
          1,
          '1',
          '1',
          '2020-05-23 03:44:08',
          'New',
          'impossiblejamb.local',
          'Heartbeat failure'
      );
  ```

  De este modo se puede ir guardando los comandos de cassandra en ficheros *.cql y ejecutar la carga de datos. Para ello se ha creado un script de bash que realiza esta tarea.

  ```bash
  #!/bin/shell
  
  #execute steps at local host
  
  host=$(hostname)
  
  echo $host
  
  echo "creating tables and types (drop if exists).."
  cqlsh $host -f create-types-tables.cql
  echo "done"
  
  sleep 1
  
  echo "inserting CIs from SQL Server...."
  cqlsh $host -f insert-sqlserver-cis-data.cql
  echo "done"
  
  sleep 1
  
  echo "adding performance counter data to CIs...."
  cqlsh $host -f add-performance-data.cql
  echo "done"
  
  sleep 1
  
  echo "adding monitor data to CIs..."
  cqlsh $host -f add-monitor-data.cql
  echo "done"
  
  
  echo "adding alerts data..."
  cqlsh $host -f add-alert-data.cql
  echo "done"
  ```

  Una vez se ha ejecutado este script los datos se cargan en el keyspace de cassandra y estan disponibles para consultas.

  Un ejemplo de ejecución del script sería el siguiente:

  ![carga_datos_cassandra_bash](images/carga_datos_cassandra_bash.png)


Una vez cargados los datos se puede conectar al cluster de cassandra y comprobar que efectivamente tenemos datos, como por ejemplo alertas:

​![consulta_datos_cassandra_1](images/consulta_datos_cassandra_1.png)

​		Pese a que este metodo en la práctica ha funcionado y es útil, no es una buena práctica en cuanto a la 		ingesta de datos. Es mejor utilizar una aproximacion por ETL (Extraction, Transform and Load).

- ##### ETL mediante el uso de Python

Durante el desarrollo de la práctica se ha valorado la definición e implementación de un proceso de ETL mediante el uso de Python. Para ello se ha diseñado el siguiente flujo para definir el proceso de carga:

![cassandra-etl-2](images/cassandra-etl-2.png)

Los pasos que se han seguido en el ETL son:

  1. SQL Server to Python pandas dataframes

     Se desea leer la información directamente desde las tablas de la base de datos y cargarlas en los dataframes de pandas. Una vez cargados los dato se pueden hacer las transformaciones pertinentes para adaptarlo al modelo de cassandra y así poder insertar los datos.

     En este caso en concreto, para evitar la configuración de conexiónes entre el entorno del dsic y SQL Server se ha hecho una exportación manual de las tablas a ficheors JSON. Estos ficheros seran pues de donde se cargaran los dataframes para proceder a su procesado.

     El codigo Python de que lee los datos de SQL y exporta el fichero de CSV que posteriormente se cargara es el siguiente:

     ```python
     import pandas as pd
     
     # Load basíc CI relational data
     ci_df = pd.read_json("../data/Configuration_Item.json")
     attributes_df = pd.read_json("../data/Attribute.json")
     
     # Load performance relational data
     rules_df = pd.read_json("../data/perfRules.json")
     rule_instances_df = pd.read_json("../data/perfRuleInstances.json")
     perf_data_df = pd.read_json("../data/perfRuleData.json")
     
     # Load monitors relational data
     monitors_df = pd.read_json("../data/Monitors.json")
     monitor_instances_df = pd.read_json("../data/MonitorInstances.json")
     monitor_instance_states_df=pd.read_json("../data/MonitorInstanceStates.json")
     health_states_df=pd.read_json("../data/HealthStates.json")
     
     #Pivot and convert CI Attributes in Map<Text,Text> for cassandra
     att_pvt=attributes_df.pivot(index="ci_id", columns="att_name")
     att_pvt.columns=['device_type','env','ip_address']
     att_pvt=att_pvt.reset_index()
                      
     def convert_att_to_JSON(r):
         return att_pvt[att_pvt.ci_id==r.ci_id][['device_type','env','ip_address']].to_dict('records')[0]
     
     att_pvt["attributes"]=att_pvt.apply(lambda r: convert_att_to_JSON(r),axis=1)
     att_pvt.drop(['device_type','env','ip_address'],axis=1,inplace=True)
     
     #Merge CIs and CI Attributes
     ci_df = pd.merge(ci_df,att_pvt,on="ci_id
     
     #calculate performance data per CI and include it in ci_df
     
     rule_instances_df.rename(columns={'per_ruleId':'ruleId'}, inplace=True)
     perf_data_df.rename(columns={'perf_rule_instId':'instance_id'}, inplace=True)
     
     perf_data=pd.merge(perf_data_df,rule_instances_df)
     perf_data=pd.merge(perf_data,rules_df)
     
     perf_data=perf_data[['ci_id','rule_name','rule_description','date','value']]\
                 .rename(\
                         columns={\
                                  'date':'collected_date',\
                                  'rule_name':'perf_rule_name',\
                                  'rule_description':'perf_rule_desc'\
                                 }\
                        )
     
     #convert date to string for cassandra conversions
     perf_data["collected_date"]=perf_data.collected_date.apply(lambda x: str(x))
     
     def get_perf_data_from_ci(r):
         return perf_data[perf_data.ci_id==r.ci_id].drop(['ci_id'],axis=1).to_dict('record')
     
     
     ci_df["performance_counters"]=ci_df.apply(lambda r: get_perf_data_from_ci(r),axis=1)
     
     #extract and model monitor information. Add it to the configuration item
     
     monitors=pd.merge(monitors_df,monitor_instances_df)
     monitors=pd.merge(monitors,monitor_instance_states_df)
     monitors.rename(columns={'health_State_id':'state_id'},inplace=True)
     monitors=pd.merge(monitors,health_states_df)
     
     monitors.drop(['monitor_id','state_id',],axis=1,inplace=True)
     monitors.rename(columns={'monitor_instance_state_id':'monitor_state_id'},inplace=True)
     
     #remove duplicates (except state values)
     monitors_agg=monitors.drop(['state_change_date','state_name','monitor_state_id'],axis=1).drop_duplicates()
     
     monitors_agg.rename(columns={'mon_isntance_id':'monitor_instance_id'},inplace=True)
     monitors.rename(columns={'state_name':'health_state'},inplace=True)
     
     
     def get_mon_states_per_monIns(r):
         r= monitors[monitors.mon_isntance_id==r.monitor_instance_id][['monitor_state_id','state_change_date','health_state']].to_dict('record')
         return r
         
     monitors_agg["monitor_states"]=monitors_agg.apply(lambda r: get_mon_states_per_monIns(r),axis=1)
     
     
     def get_monitors_from_ci(r):
         return monitors_agg[monitors_agg.ci_id==r.ci_id].drop('ci_id',axis=1).to_dict('record')
     
     ci_df["monitors"]=ci_df.apply(lambda r: get_monitors_from_ci(r),axis=1)
     
     #export Configuration items data to CSV
     ci_df.to_csv('ci_data.csv',sep='|',index=False)
     ```

     

  2. Pandas dataframe to CSV

     Una vez los dataframes estan listos, se hace una exportación al CSV (siguiendo un formato específico mediante notaciones JSON en columnas de tipos complejos para cassandra)

  3. Carga de datos en cassandra con la tool dsbulk

     Por ultimo, se realiza una carga de datos a cassandra directamente del CSV mediante le uso de dsbulk. Esta herramienta ha sido desarrollada por Datastax y permite cargar datos desde ficheros con formato CSV y JSON. 

     A continuación se muestra el comando utilizado para la carga de datos del CSV. En este caso en concreto se hace para la tabla Configuration Items.

     1. Truncamos la tabla para vaciarla y comprobamos que no hay datos

        ![truncate-select-cassandra](images/truncate-select-cassandra.png)

     2. Cargamos datos desde Shell

        ```bash
        dsbulk load -url ci_data.csv -k sysmonitor -t configuration_item -h NOSQL-025-1 -delim '|' --connector.csv.maxCharsPerColumn -1 --schema.allowMissingFields true
        ```

        ![dsbulk-cassandra](images/dsbulk-cassandra.png)

     ​	

     3. Ejecutamos una consulta sencilla para comprobar la carga de datos:

        ```cassandra
        select ci_id,attributes,name from sysmonitor.configuration_item where ci_id =1;
        ```

        ![cassandra-query-1](images/cassandra-query-1.png)

     ​		

     **NOTA**: Para instalar dsbulk en el servidor de Cassandra se ha seguido la guia oficial de datastax https://docs.datastax.com/en/dsbulk/doc/dsbulk/install/dsbulkInstall.html

### Consultas

Una vez se han cargado los datos en el modelo de casandra, pasamos a ver como realizar las [consultas](#Consultas) claves del sistema implementado. 

**NOTA**: En el caso de cassandra, el lenguaje de consultas CQL es limitado y solo permite realizar consultas basícas con filtros sencillos. Cualquier tipo de agregacion o acceso a tipos de datos complejos o custom, debe ser realizado a nivel de aplicativo.

A continuación mostramos las consultas planteadas:


- Consulta 1 - **Listado de alertas con prioridad New:**

  Esta consulta se puede efectuar desde CQL ya que la clave de partición de las alertas es el estado de la alerta y por eso es que se puede realizar el filtro en la consulta.

  ```cassandra
  select 
  	ci_name, 
  	alert_name, 
  	alert_state_name,
  	state_change_date 
  from sysmonitor.alert 
  	where alert_state_name = 'New' 
  limit 15;
  ```

  ![cassandra-consulta-1](images/cassandra-consulta-1.png)

  

- Consulta 2 - **Obtener los cambios de estado para el monitor ``Heartbeat Monitor`` para el servidor ``productivetrue.local``**

  Esta consulta no se puede realizar 100% con CQL. El motivo es que el monitor hertbeat esta contenido en la lista de monitores de cada CI. Por lo que desde CQL podremos entraer todos los datos del CI en concreto pero no podremos hacer nada mas. Los otros filtrados deberan hacerse a nivel de aplicación. Para ello se ha desarrollado un codigo python que cumple con el cometido.

  ```cassandra
  select * from sysmonitor.configuration_item WHERE name = 'productivetrue.local';
  ```

  ![cassandra-consulta-2-cql](images/cassandra-consulta-2-cql.png)



​		Se observa como la cantidad de informacion es tran grande que en la consola no se puede ver bien. Adicionalmente, tal y como se ha comentado anteriormente, no se puede hacer mas filtro que por el nombre del CI. El resto debe hacerse desde el aplicativo. Para ello se ha desarrollado el siguiente codigo Python:

```python
from cassandra.cluster import Cluster
import json

#Connec to cassandra cluster
cluster = Cluster(['nosql-025-1'],port=9042)
session = cluster.connect('sysmonitor',wait_for_all_pools=True)
session.execute('USE sysmonitor')

#retrieve data from cassandra
rows = session.execute("select * from sysmonitor.configuration_item WHERE name = 'productivetrue.local';")

#define result as json
res={}

#work with cassandra resultset
for r in rows:
        res["ci_id"]=r.ci_id
        res["ci_name"]=r.name
        #print(r.monitors)
        for m in r.monitors:
                if m.name=="Heartbeat Monitor":
                        res["monitor.name"]=m.name

                        states=[]
                        for m_state in m.monitor_states:
                                st={}
                                st["monitor_state_id"]=m_state.monitor_state_id
                                st["state_change_date"]=str(m_state.state_change_date)
                                st["health_state"]=m_state.health_state
                                states.append(st)

                        res['states']=states


print(json.dumps(res))
```

![cassandra-query-2-python](images/cassandra-query-2-python.png)



- Consulta 3 - **Obtener datos recolectados por la regla de rendimiento `% Processor Usage` para el CI `productivetrue.local`:**

  

  En este caso, al igual que en la consulta 2, se debe hacer la consulta a traves del aplicativo. En cassandra extraeremos todos los datos del CI `productivetrue.local` y en la aplicacion realizamos el resto de operaciones.

  La consulta CQL es:

  ```cassandra
  select * from sysmonitor.configuration_item WHERE name = 'productivetrue.local';
  ```

  El codigo python de la aplicacion es el siguiente:

  ```python
  from cassandra.cluster import Cluster
  import json
  
  #Connec to cassandra cluster
  cluster = Cluster(['nosql-025-1'],port=9042)
  session = cluster.connect('sysmonitor',wait_for_all_pools=True)
  session.execute('USE sysmonitor')
  
  #retrieve data from cassandra
  rows = session.execute("select * from sysmonitor.configuration_item WHERE name = 'productivetrue.local';")
  
  #define result as json
  res={}
  
  #work with cassandra resultset
  for r in rows:
          res["ci_id"]=r.ci_id
          res["ci_name"]=r.name
  
          performance_data=[]
          #print(r.monitors)
          for pc in r.performance_counters:
                  if pc.perf_rule_name=="% Processor usage":
                          perf_data={}
                          perf_data["performance Rule"]=pc.perf_rule_name
                          perf_data["collected_date"]=str(pc.collected_date)
                          perf_data["value"]=pc.value
                          performance_data.append(perf_data)
  
          res['performance_data']=performance_data
  
  
  print(json.dumps(res))
  ```

  ![cassandra-query-3](images/cassandra-query-3.png)

  

  

  

## MongoDB

### Infraestructura y despliegue del cluster mongo

Comenzamos describiendo la arquitectura del cluster de mongo implementada.

- 3 nodos de réplica:
  - **mongos1n1**, **mongos1n2** y **mongos1n3**
- 3 config servers: 
  - **mongocfg1, mongocfg2 y mongocfg3**
- 2 servidores mongos para rutar las peticiones de clientes:
  - **mongos1 y mongos2**



![Image title](https://image.ibb.co/ke9P2F/Screen_Shot_2017_08_02_at_13_45_21.png)



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
        - ~/nosql/source:/source
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

El fichero de Composer es bastante descriptivo: levantará un docker por cada uno de los nodos descritos previamente haciendo uso de la imagen mongo de Docker y arrancándolos con diferentes parámetros en función de su rol en el cluster.

Con respecto a los volúmenes montados para cada uno merece la pena comentar que:

 - Todos los contenedores montarán en `/etc/localtime` el volumen del host  `~/nosql/mongo_cluster/localtime`. Esa ruta local no es más que un enlace simbólico al fichero `/etc/localtime` de la máquina host. No se ha montado directamente por restricciones de seguridad de Docker en OSX. Por defecto no permite montar la ruta /etc del host. El objetivo de esta configuración, es que todos los contenedores compartan la configuración horaria con entre ellos y con el host.

 - Los contenedores dedicados a replicar la configuración y los shards de datos, almacenarán la información en `/nosql/mongo_cluster/configX` y `/nosql/mongo_cluster/dataX` respectivamente, siendo X el número que identifica al nodo en el set. Los contenedores de los routers no necesitan almacenar ningún tipo de información, ya que simplemente se limitarán a rutar las conexiónes de los clientes.

 -  El nodo1 del shard de datos `mongors1n1` monta el volumen del host `~/nosql/source` en `/source` con el fin de tener accesibles los ficheros fuente necesarios para la importación.

   

Tras ejecutar `docker compose up`, podemos comprobar que se han levantado todos los nodos que conforman la arquitectura:

```bash
CONTAINER ID    IMAGE       COMMAND                  CREATED         STATUS          PORTS                      NAMES
082dd7e0e899    mongo       "docker-entrypoint.s…"   37 minutes ago  Up 15 minutes   0.0.0.0:27020->27017/tcp   mongos2
6ce9bec6177d    mongo       "docker-entrypoint.s…"   37 minutes ago  Up 15 minutes   0.0.0.0:27019->27017/tcp   mongos1
1a00b0558347    mongo       "docker-entrypoint.s…"   37 minutes ago  Up 15 minutes   0.0.0.0:27017->27017/tcp   mongors1n1
86b1e7786e9a    mongo       "docker-entrypoint.s…"   37 minutes ago  Up 15 minutes   27017/tcp                  mongocfg2
3d9c7b2ced01    mongo       "docker-entrypoint.s…"   37 minutes ago  Up 15 minutes   0.0.0.0:27037->27017/tcp   mongors1n3
840d45fb27eb    mongo       "docker-entrypoint.s…"   37 minutes ago  Up 15 minutes   27017/tcp                  mongocfg1
f6f2c8c7351a    mongo       "docker-entrypoint.s…"   37 minutes ago  Up 15 minutes   27017/tcp                  mongocfg3
68bd894e1157    mongo       "docker-entrypoint.s…"   37 minutes ago  Up 15 minutes   0.0.0.0:27027->27017/tcp   mongors1n2
```

Inicializamos el set de réplicas de configuración ejecutando el siguiente comando sobre el contenedor mongocfg1 (uno de los servidores de configuración mongo):

```bash
❯ docker exec -it mongocfg1 bash -c "echo 'rs.initiate({_id: \"mongors1conf\",configsvr: true, members: [{ _id : 0, host : \"mongocfg1\" },{ _id : 1, host : \"mongocfg2\" }, { _id : 2, host : \"mongocfg3\" }]})' | mongo"
```

Inicializamos el shard de datos sobre los nodos mongors1n1, mongors1n2 y mongors1n3:

```bash
❯ docker exec -it mongors1n1 bash -c "echo 'rs.initiate({_id : \"mongors1\", members: [{ _id : 0, host : \"mongors1n1\" },{ _id : 1, host : \"mongors1n2\" },{ _id : 2, host : \"mongors1n3\" }]})' | mongo"
```

Comprobamos con `rs.status()` que el replica set de configuración está correctamente inicializado (en mongocfg1) y repetimos la operación para verificar el shard para datos en mongors1n1.

Podemos comprobar que ya tenemos un shard de nombre **mongors1** y que los tres nodos que hemos configurado pueden verlo:

```bash
❯ docker exec -it mongors1n1 bash -c "echo 'rs.status()' | mongo"
MongoDB shell version v4.2.8
connecting to: mongodb://127.0.0.1:27017/?compressors=disabled&gssapiServiceName=mongodb
Implicit session: session { "id" : UUID("a6b894cc-b029-4645-a007-af20afdec868") }
MongoDB server version: 4.2.8
{
        "set" : "mongors1",
        "date" : ISODate("2020-06-28T10:50:48.423Z"),
        "myState" : 1,
        "term" : NumberLong(1),
        "syncingTo" : "",
        "syncSourceHost" : "",
        "syncSourceId" : -1,
        "heartbeatIntervalMillis" : NumberLong(2000),
        "majorityVoteCount" : 2,
        "writeMajorityCount" : 2,
        "optimes" : {
                "lastCommittedOpTime" : {
                        "ts" : Timestamp(1593341442, 1),
                        "t" : NumberLong(1)
                },
                "lastCommittedWallTime" : ISODate("2020-06-28T10:50:42.702Z"),
                "readConcernMajorityOpTime" : {
                        "ts" : Timestamp(1593341442, 1),
                        "t" : NumberLong(1)
                },
                "readConcernMajorityWallTime" : ISODate("2020-06-28T10:50:42.702Z"),
                "appliedOpTime" : {
                        "ts" : Timestamp(1593341442, 1),
                        "t" : NumberLong(1)
                },
                "durableOpTime" : {
                        "ts" : Timestamp(1593341442, 1),
                        "t" : NumberLong(1)
                },
                "lastAppliedWallTime" : ISODate("2020-06-28T10:50:42.702Z"),
                "lastDurableWallTime" : ISODate("2020-06-28T10:50:42.702Z")
        },
        "lastStableRecoveryTimestamp" : Timestamp(1593341432, 3),
        "lastStableCheckpointTimestamp" : Timestamp(1593341432, 3),
        "electionCandidateMetrics" : {
                "lastElectionReason" : "electionTimeout",
                "lastElectionDate" : ISODate("2020-06-28T10:50:32.672Z"),
                "electionTerm" : NumberLong(1),
                "lastCommittedOpTimeAtElection" : {
                        "ts" : Timestamp(0, 0),
                        "t" : NumberLong(-1)
                },
                "lastSeenOpTimeAtElection" : {
                        "ts" : Timestamp(1593341421, 1),
                        "t" : NumberLong(-1)
                },
                "numVotesNeeded" : 2,
                "priorityAtElection" : 1,
                "electionTimeoutMillis" : NumberLong(10000),
                "numCatchUpOps" : NumberLong(0),
                "newTermStartDate" : ISODate("2020-06-28T10:50:32.701Z"),
                "wMajorityWriteAvailabilityDate" : ISODate("2020-06-28T10:50:33.186Z")
        },
        "members" : [
                {
                        "_id" : 0,
                        "name" : "mongors1n1:27017",
                        "health" : 1,
                        "state" : 1,
                        "stateStr" : "PRIMARY",
                        "uptime" : 71,
                        "optime" : {
                                "ts" : Timestamp(1593341442, 1),
                                "t" : NumberLong(1)
                        },
                        "optimeDate" : ISODate("2020-06-28T10:50:42Z"),
                        "syncingTo" : "",
                        "syncSourceHost" : "",
                        "syncSourceId" : -1,
                        "infoMessage" : "could not find member to sync from",
                        "electionTime" : Timestamp(1593341432, 1),
                        "electionDate" : ISODate("2020-06-28T10:50:32Z"),
                        "configVersion" : 1,
                        "self" : true,
                        "lastHeartbeatMessage" : ""
                },
                {
                        "_id" : 1,
                        "name" : "mongors1n2:27017",
                        "health" : 1,
                        "state" : 2,
                        "stateStr" : "SECONDARY",
                        "uptime" : 27,
                        "optime" : {
                                "ts" : Timestamp(1593341442, 1),
                                "t" : NumberLong(1)
                        },
                        "optimeDurable" : {
                                "ts" : Timestamp(1593341442, 1),
                                "t" : NumberLong(1)
                        },
                        "optimeDate" : ISODate("2020-06-28T10:50:42Z"),
                        "optimeDurableDate" : ISODate("2020-06-28T10:50:42Z"),
                        "lastHeartbeat" : ISODate("2020-06-28T10:50:46.686Z"),
                        "lastHeartbeatRecv" : ISODate("2020-06-28T10:50:47.223Z"),
                        "pingMs" : NumberLong(0),
                        "lastHeartbeatMessage" : "",
                        "syncingTo" : "mongors1n1:27017",
                        "syncSourceHost" : "mongors1n1:27017",
                        "syncSourceId" : 0,
                        "infoMessage" : "",
                        "configVersion" : 1
                },
                {
                        "_id" : 2,
                        "name" : "mongors1n3:27017",
                        "health" : 1,
                        "state" : 2,
                        "stateStr" : "SECONDARY",
                        "uptime" : 27,
                        "optime" : {
                                "ts" : Timestamp(1593341442, 1),
                                "t" : NumberLong(1)
                        },
                        "optimeDurable" : {
                                "ts" : Timestamp(1593341442, 1),
                                "t" : NumberLong(1)
                        },
                        "optimeDate" : ISODate("2020-06-28T10:50:42Z"),
                        "optimeDurableDate" : ISODate("2020-06-28T10:50:42Z"),
                        "lastHeartbeat" : ISODate("2020-06-28T10:50:46.686Z"),
                        "lastHeartbeatRecv" : ISODate("2020-06-28T10:50:47.223Z"),
                        "pingMs" : NumberLong(0),
                        "lastHeartbeatMessage" : "",
                        "syncingTo" : "mongors1n1:27017",
                        "syncSourceHost" : "mongors1n1:27017",
                        "syncSourceId" : 0,
                        "infoMessage" : "",
                        "configVersion" : 1
                }
        ],
        "ok" : 1,
        "$clusterTime" : {
                "clusterTime" : Timestamp(1593341442, 1),
                "signature" : {
                        "hash" : BinData(0,"AAAAAAAAAAAAAAAAAAAAAAAAAAA="),
                        "keyId" : NumberLong(0)
                }
        },
        "operationTime" : Timestamp(1593341442, 1)
}
bye
```

Ya podemos mostrar el shard mongors1 a los routers:

```bash
❯ docker exec -it mongos1 bash -c "echo 'sh.addShard(\"mongors1/mongors1n1\")' | mongo "
MongoDB shell version v4.2.8
connecting to: mongodb://127.0.0.1:27017/?compressors=disabled&gssapiServiceName=mongodb
Implicit session: session { "id" : UUID("d9025c60-eba3-4d3d-929a-e666794be22f") }
MongoDB server version: 4.2.8
{
        "shardAdded" : "mongors1",
        "ok" : 1,
        "operationTime" : Timestamp(1593341557, 7),
        "$clusterTime" : {
                "clusterTime" : Timestamp(1593341557, 7),
                "signature" : {
                        "hash" : BinData(0,"AAAAAAAAAAAAAAAAAAAAAAAAAAA="),
                        "keyId" : NumberLong(0)
                }
        }
}
bye
```

Ahora ya podemos proceder a la creación de nuestra base de datos, que llamaremos `sysmonitor`. Tras la creación habilitaremos el shardening:

```bash
❯ docker exec -it mongors1n1 bash -c "echo 'use sysmonitor' | mongo" 
❯ docker exec -it mongos1 bash -c "echo 'sh.enableSharding(\"sysmonitor\")' | mongo "
```



Comprobamos que todo ha funcionado como esperábamos. Efectivamente vemos el shard mongors1 desde uno de los routers, y también ambas bases de datos: la de configuración y la que acabamos de crear, aunque aún no tenemos shard key definida.

```bash
❯ docker exec -it mongos1 bash -c "echo 'sh.status()' | mongo"                       
MongoDB shell version v4.2.8
connecting to: mongodb://127.0.0.1:27017/?compressors=disabled&gssapiServiceName=mongodb
Implicit session: session { "id" : UUID("65bdb589-bbda-43cf-a30c-6c654716242c") }
MongoDB server version: 4.2.8
--- Sharding Status --- 
  sharding version: {
        "_id" : 1,
        "minCompatibleVersion" : 5,
        "currentVersion" : 6,
        "clusterId" : ObjectId("5ef875eac5e6ff49bccb2a3f")
  }
  shards:
        {  "_id" : "mongors1",  "host" : "mongors1/mongors1n1:27017,mongors1n2:27017,mongors1n3:27017",  "state" : 1 }
  active mongoses:
        "4.2.8" : 2
  autosplit:
        Currently enabled: yes
  balancer:
        Currently enabled:  yes
        Currently running:  no
        Failed balancer rounds in last 5 attempts:  0
        Migration Results for the last 24 hours: 
                No recent migrations
  databases:
        {  "_id" : "config",  "primary" : "config",  "partitioned" : true }
                config.system.sessions
                        shard key: { "_id" : 1 }
                        unique: false
                        balancing: true
                        chunks:
                                mongors1        1024
                        too many chunks to print, use verbose if you want to force print
        {  "_id" : "sysmonitor",  "primary" : "mongors1",  "partitioned" : true,  "version" : {  "uuid" : UUID("71365c44-3606-4b6f-8c16-de20e49217ab"),  "lastMod" : 1 } }

bye
```



#### Comandos útiles para la gestión de la infrastructura

Despliegue del cluster:

```
❯ docker-compose up
```

Arranque del mongo cluster:

```bash
❯ docker start mongos2 mongos1 mongors1n1 mongocfg2 mongors1n3 mongocfg1 mongocfg3 mongors1n2
```

Parada mongo cluster:

```bash
❯ docker start mongos2 mongos1 mongors1n1 mongocfg2 mongors1n3 mongocfg1 mongocfg3 mongors1n2
```

<u>Borrar TODO el cluster de mongo</u>:

```bash
❯ docker rm mongos2 mongos1 mongors1n1 mongocfg2 mongors1n3 mongocfg1 mongocfg3 mongors1n2
```



### Agregación e importación de datos

Con el fin de importar los datos en mongo, se comienza exportando cada una de las tablas de la base de datos relacional en formato json. Puesto que las relaciones definidas en la base de datos relacional son todas uno a muchos, existe una tabla por cada una de las entidades definidas en el esquema.



Con el siguiente script en Python, se cargan ambos los ficheros json con las tablas relacionales y se generan dos ficheros json. El primero contendrá un array con los documentos que representan los CIs, mientras que el segundo corresponderá al listado de documentos de alertas.

```python
import pandas as pd
import json
import numpy as np    

# Load basíc CI relational data
ci_df = pd.read_json("../sql/Configuration_Item.json")
attributes_df = pd.read_json("../sql/Attribute.json")

# Load performance relational data
rules_df = pd.read_json("../sql/perfRules.json")
rule_instances_df = pd.read_json("../sql/perfRuleInstances.json")
perf_data_df = pd.read_json("../sql/perfRuleData.json")

# Load monitors relational data
monitors_df = pd.read_json("../sql/Monitors.json")
monitor_instances_df = pd.read_json("../sql/MonitorInstances.json")
monitor_instance_states_df=pd.read_json("../sql/MonitorInstanceStates.json")
health_states_df=pd.read_json("../sql/HealthStates.json").set_index('state_id')

# Load alert instances relational data
alert_instances_df = pd.read_json("../sql/AlertInstances.json")
alert_states_df = pd.read_json("../sql/AlertStates.json").set_index("state_id")


# Merge CI and attributes data into one dataframe
ci_att_df = pd.merge(ci_df,attributes_df,on="ci_id")
# We apply dataframe pivot operation to convert attribute values into columns
cp=ci_att_df.pivot(index="name", columns="att_name")
# Rename columns
cp.columns = ['ci_id','ci_id2','ci_id3','device_type','env','ip_address']
cp.drop(columns=['ci_id2', 'ci_id3'], inplace=True)
configuration_items=cp.reset_index()
monitor_instances_df = pd.merge(monitor_instances_df,monitors_df,on="monitor_id")

# Merge performance dataframes
rule_instances_df.rename(columns={'per_ruleId':'ruleId'}, inplace=True)
rule_instances_df = pd.merge(ci_df,rule_instances_df,on="ci_id")
rule_instances = pd.merge(rule_instances_df,rules_df,on="ruleId")
rule_instances.sort_values('ci_id')

# Merge alert dataframes
alert_instances_df = pd.merge(alert_instances_df,monitor_instances_df,on="mon_isntance_id" )
alert_instances_df = pd.merge(alert_instances_df,ci_df, on="ci_id")
alert_instances_df = alert_instances_df.loc[:,['alert_name','alert_description','name_y','state_change_date','priority']]
alert_instances_df.rename(columns={'name_y':'configuration_item'}, inplace=True)



configuration_item_documents= []

# Generate configuration_items documents
for ci_index, configuration_item in configuration_items.iterrows():
    ci = json.loads(configuration_item.to_json())
    
    # Attach performance rules instances to CIs
    ci["performance_rules"]=[]
    for rule_index, rule_instance in rule_instances[rule_instances["ci_id"]==ci["ci_id"]].loc[:,'ruleId':'rule_description'].iterrows():
        rule = json.loads(rule_instance.to_json())
        
        # Attach performance data to rules
        data = []
        for perf_data_index, perf_data in perf_data_df[perf_data_df["perf_rule_instId"]==rule["ruleId"]].loc[:,'value':'date'].iterrows():
            d = json.loads(perf_data.to_json())
            data.append(d)
        rule["data"]=data
        ci["performance_rules"].append(rule)
        
    # Attach monitor instances to CIs
    ci["monitors"]= []
    
    for monitor_index, monitor_instance in monitor_instances_df[monitor_instances_df["ci_id"]==ci["ci_id"]].loc[:,['mon_isntance_id','name','description']].iterrows():
        monitor = json.loads(monitor_instance.to_json())
        
        # Attach health state changes to monitor instances
        states = []
        
        for monitor_instance_index, monitor_instance_state in monitor_instance_states_df[monitor_instance_states_df["mon_isntance_id"]==monitor["mon_isntance_id"]].loc[:,['state_change_date','health_State_id']].iterrows():
            state_id=int(monitor_instance_state["health_State_id"])-1
            monitor_instance_state["health_State_id"] = health_states_df.iloc[state_id].state_name
            currentState = json.loads(monitor_instance_state.to_json())
            states.append(currentState)
        
        monitor["states"]=states
        
        ci["monitors"].append(monitor)
    
    configuration_item_documents.append(ci)

# Save ci documents
with open('../nosql/cis.json', 'w') as fout:
    fout.write(json.dumps(configuration_item_documents, indent=4))    

    
# Generate alert documents    
    
alert_documents = []

for alert_index, alert_row in alert_instances_df.iterrows():
    alert = json.loads(alert_row.to_json())
    priority_id=int(alert_row["priority"])-1
    alert['priority']= alert_states_df.iloc[priority_id].state_name
    alert_documents.append(alert)
    
# Save alerts documents
with open('../nosql/alerts.json', 'w') as fout:
    fout.write(json.dumps(alert_documents, indent=4)) 
    
```

El fichero `cis.json` contendrá un array json con un documento por cada Configuration_Item. A continuación se muestra parte uno de los documentos contenidos , que representa un CI. Se han reducido los datos de rendimiento para minimizar la salida.

```json
[
{
        "name": "austeredear.local",
        "ci_id": 17,
        "device_type": "server",
        "env": "dev",
        "ip_address": "185.206.227.93",
        "performance_rules": [
            {
                "ruleId": 23,
                "rule_name": "% Processor usage",
                "rule_description": "% Processor usage",
                "data": [
                    {
                        "value": 21,
                        "date": 1590192000000
                    },
                    {
                        "value": 25,
                        "date": 1590192300000
                    },
                  	....
                    {
                        "value": 21,
                        "date": 1590281700000
                    }
                ]
            }
        ],
        "monitors": [
            {
                "mon_isntance_id": 17,
                "name": "Heartbeat Monitor",
                "description": "This monitor checks if the device is up",
                "states": [
                    {
                        "state_change_date": "2020-05-17T03:24:00",
                        "health_State_id": "Healthy"
                    },
                    {
                        "state_change_date": "2020-05-23T03:44:04",
                        "health_State_id": "Critical"
                    },
                    {
                        "state_change_date": "2020-05-23T04:15:59",
                        "health_State_id": "Healthy"
                    }
                ]
            },
            {
                "mon_isntance_id": 251,
                "name": "Process Ssh",
                "description": "This process monitor watches for the Ssh Daemon process to be running.",
                "states": [
                    {
                        "state_change_date": "2020-05-17T15:25:00",
                        "health_State_id": "Healthy"
                    }
                ]
            },
            {
                "mon_isntance_id": 252,
                "name": "Operating System Available MBytes",
                "description": "Available megabytes of memory is low. System performance may be adversely affected.  The available megabytes memory value represents the sum of MemFree, Buffers and Cached as reported by the operating system.",
                "states": [
                    {
                        "state_change_date": "2020-05-17T02:51:00",
                        "health_State_id": "Healthy"
                    }
                ]
            }
        ]
    },
	  ...
]
```

El fichero `alerts.json` contendrá el listado de documentos que representan las alertas. 

```json
[
    {
        "alert_name": "Heartbeat failure",
        "alert_description": "The device is not sending heartbeats",
        "configuration_item": "impossiblejamb.local",
        "state_change_date": "2020-05-23T03:44:08",
        "priority": "New"
    },
    {
        "alert_name": "Heartbeat failure",
        "alert_description": "The device is not sending heartbeats",
        "configuration_item": "rubberyclock.local",
        "state_change_date": "2020-05-23T03:44:37",
        "priority": "New"
    },
    {
        "alert_name": "Heartbeat failure",
        "alert_description": "The device is not sending heartbeats",
        "configuration_item": "wrytug.local",
        "state_change_date": "2020-05-23T03:44:27",
        "priority": "New"
    },
  ...
]
```



Como se menciona anteriormente, en el primer nodo de las réplicas de datos hemos exportado un directorio de la máquina host donde se han guardado los ficheros json generados. Ejecutamos `mongoimport` para importar los documentos del json generado en la colección `configuration_item` :

```bash
❯ docker exec -it mongors1n1 bash -c "mongoimport -d sysmonitor -c configuration_item --jsonArray --type=json /source/cis.json"
2020-06-28T21:24:19.481+0200    connected to: mongodb://localhost/
2020-06-28T21:24:19.615+0200    100 document(s) imported successfully. 0 document(s) failed to import.

```



Comprobamos con un simple `find()` que los documentos se han cargado correctamente. A continuación se muestran tan sólo algunos atributos del CI de nombre ``productivetrue.local``

```bash
❯ docker exec -it mongos1 bash -c "echo -e 'use sysmonitor \n db.configuration_item.find({ \"name\":\"productivetrue.local\"}, { name: 1, ip_address: 1, env: 1 } ).pretty()' | mongo"             
MongoDB shell version v4.2.8
connecting to: mongodb://127.0.0.1:27017/?compressors=disabled&gssapiServiceName=mongodb
Implicit session: session { "id" : UUID("f1632408-b566-4d1f-a491-84b73c8f4344") }
MongoDB server version: 4.2.8
switched to db sysmonitor
{
        "_id" : ObjectId("5ef8ee639f3bb1c5cbbbbe77"),
        "name" : "productivetrue.local",
        "env" : "dev",
        "ip_address" : "6.2.24.168"
}
bye
```



Importamos ahora los documentos que representan las alertas:

```bash
❯ docker exec -it mongors1n1 bash -c "mongoimport -d sysmonitor -c alerts --jsonArray --type=json /source/alerts.json"
2020-06-29T01:22:21.455+0200    connected to: mongodb://localhost/
2020-06-29T01:22:21.524+0200    100 document(s) imported successfully. 0 document(s) failed to import.
```



Verificamos el contenido de la colección:

```bash
❯ docker exec -it mongos1 bash -c "echo -e 'use sysmonitor \n db.alerts.find()' | mongo"
MongoDB shell version v4.2.8
connecting to: mongodb://127.0.0.1:27017/?compressors=disabled&gssapiServiceName=mongodb
Implicit session: session { "id" : UUID("dca0ecbd-529f-451d-b575-09ae920d90d0") }
MongoDB server version: 4.2.8
switched to db sysmonitor
{ "_id" : ObjectId("5ef9262de267e9c00481f20a"), "alert_name" : "Heartbeat failure", "alert_description" : "The device is not sending heartbeats", "configuration_item" : "rubberyclock.local", "state_change_date" : "2020-05-23T03:44:37", "priority" : "New" }
{ "_id" : ObjectId("5ef9262de267e9c00481f20b"), "alert_name" : "Heartbeat failure", "alert_description" : "The device is not sending heartbeats", "configuration_item" : "wrytug.local", "state_change_date" : "2020-05-23T03:44:27", "priority" : "New" }
{ "_id" : ObjectId("5ef9262de267e9c00481f20c"), "alert_name" : "Heartbeat failure", "alert_description" : "The device is not sending heartbeats", "configuration_item" : "worstblip.local", "state_change_date" : "2020-05-23T03:44:12", "priority" : "New" }
{ "_id" : ObjectId("5ef9262de267e9c00481f20d"), "alert_name" : "Heartbeat failure", "alert_description" : "The device is not sending heartbeats", "configuration_item" : "lastbuyer.local", "state_change_date" : "2020-05-23T03:44:21", "priority" : "New" }
{ "_id" : ObjectId("5ef9262de267e9c00481f20e"), "alert_name" : "Heartbeat failure", "alert_description" : "The device is not sending heartbeats", "configuration_item" : "rapidhinge.local", "state_change_date" : "2020-05-23T03:44:32", "priority" : "New" }
{ "_id" : ObjectId("5ef9262de267e9c00481f20f"), "alert_name" : "Heartbeat failure", "alert_description" : "The device is not sending heartbeats", "configuration_item" : "productivetrue.local", "state_change_date" : "2020-05-23T03:44:36", "priority" : "New" }
{ "_id" : ObjectId("5ef9262de267e9c00481f210"), "alert_name" : "Heartbeat failure", "alert_description" : "The device is not sending heartbeats", "configuration_item" : "extraneousbent.local", "state_change_date" : "2020-05-23T03:44:40", "priority" : "New" }
...

```



### Consultas realizadas

Procedemos a conectarnos directamente a la shell de mongo para efectuar de una manera más cómoda consultas que nos ayuden a comprobar que la información se importó correctamente y que podemos consultar los datos de una forma eficiente:

Iniciamos una shell interactiva de mongo en uno de los routers y hacemos una consulta para ver que las colecciones son accesibles. Comprobamos que hay 23 CIs de tipo 'server' al igual que en la base de datos relacional usada como fuente.:

```bash
❯ docker exec -it mongos1 mongo
MongoDB shell version v4.2.8
connecting to: mongodb://127.0.0.1:27017/?compressors=disabled&gssapiServiceName=mongodb
Implicit session: session { "id" : UUID("d9b0b540-1278-4a88-a906-5bb68ac31ce3") }
MongoDB server version: 4.2.8
mongos> use sysmonitor
switched to db sysmonitor
mongos> db.configuration_item.find({"device_type": "server"}).length()
23
mongos> DBQuery.shellBatchSize = 300
300
mongos> db.configuration_item.find({"device_type": "server"},{"name":"1"})
{ "_id" : ObjectId("5ef8ee639f3bb1c5cbbbbe42"), "name" : "austeredear.local" }
{ "_id" : ObjectId("5ef8ee639f3bb1c5cbbbbe49"), "name" : "classicslang.local" }
{ "_id" : ObjectId("5ef8ee639f3bb1c5cbbbbe4b"), "name" : "discreteexit.local" }
{ "_id" : ObjectId("5ef8ee639f3bb1c5cbbbbe4c"), "name" : "dopeycell.local" }
{ "_id" : ObjectId("5ef8ee639f3bb1c5cbbbbe4e"), "name" : "extraneousbent.local" }
{ "_id" : ObjectId("5ef8ee639f3bb1c5cbbbbe52"), "name" : "frigidkiwi.local" }
{ "_id" : ObjectId("5ef8ee639f3bb1c5cbbbbe53"), "name" : "grotesqueforty.local" }
{ "_id" : ObjectId("5ef8ee639f3bb1c5cbbbbe55"), "name" : "grouchybaker.local" }
{ "_id" : ObjectId("5ef8ee639f3bb1c5cbbbbe56"), "name" : "helpfulduet.local" }
{ "_id" : ObjectId("5ef8ee639f3bb1c5cbbbbe5a"), "name" : "heftystrum.local" }
{ "_id" : ObjectId("5ef8ee639f3bb1c5cbbbbe62"), "name" : "infatuatedomega.local" }
{ "_id" : ObjectId("5ef8ee639f3bb1c5cbbbbe6a"), "name" : "neglectedmouse.local" }
{ "_id" : ObjectId("5ef8ee639f3bb1c5cbbbbe6e"), "name" : "palehoagy.local" }
{ "_id" : ObjectId("5ef8ee639f3bb1c5cbbbbe77"), "name" : "productivetrue.local" }
{ "_id" : ObjectId("5ef8ee639f3bb1c5cbbbbe7d"), "name" : "shimmeringtomb.local" }
{ "_id" : ObjectId("5ef8ee639f3bb1c5cbbbbe7e"), "name" : "spottedbody.local" }
{ "_id" : ObjectId("5ef8ee639f3bb1c5cbbbbe81"), "name" : "squarenasal.local" }
{ "_id" : ObjectId("5ef8ee639f3bb1c5cbbbbe87"), "name" : "tediouslat.local" }
{ "_id" : ObjectId("5ef8ee639f3bb1c5cbbbbe88"), "name" : "unsungsugar.local" }
{ "_id" : ObjectId("5ef8ee639f3bb1c5cbbbbe8a"), "name" : "urbanfast.local" }
{ "_id" : ObjectId("5ef8ee639f3bb1c5cbbbbe8c"), "name" : "usefulname.local" }
{ "_id" : ObjectId("5ef8ee639f3bb1c5cbbbbe97"), "name" : "vengefulpick.local" }
{ "_id" : ObjectId("5ef8ee639f3bb1c5cbbbbe98"), "name" : "zanydip.local" }
```



A continuación mostramos las consultas planteadas:



**Listado de alertas con prioridad New:**  

```bash
mongos> db.alerts.find({"priority":"New"},{"_id":0, "alert_name":"1", "alert_description":"1", "configuration_item":"1", "state_change_date":"1"})

{ "alert_name" : "Heartbeat failure", "alert_description" : "The device is not sending heartbeats", "configuration_item" : "rubberyclock.local", "state_change_date" : "2020-05-23T03:44:37" }
{ "alert_name" : "Heartbeat failure", "alert_description" : "The device is not sending heartbeats", "configuration_item" : "wrytug.local", "state_change_date" : "2020-05-23T03:44:27" }
{ "alert_name" : "Heartbeat failure", "alert_description" : "The device is not sending heartbeats", "configuration_item" : "worstblip.local", "state_change_date" : "2020-05-23T03:44:12" }
{ "alert_name" : "Heartbeat failure", "alert_description" : "The device is not sending heartbeats", "configuration_item" : "lastbuyer.local", "state_change_date" : "2020-05-23T03:44:21" }
{ "alert_name" : "Heartbeat failure", "alert_description" : "The device is not sending heartbeats", "configuration_item" : "rapidhinge.local", "state_change_date" : "2020-05-23T03:44:32" }
{ "alert_name" : "Heartbeat failure", "alert_description" : "The device is not sending heartbeats", "configuration_item" : "productivetrue.local", "state_change_date" : "2020-05-23T03:44:36" }
{ "alert_name" : "Heartbeat failure", "alert_description" : "The device is not sending heartbeats", "configuration_item" : "extraneousbent.local", "state_change_date" : "2020-05-23T03:44:40" }
{ "alert_name" : "Heartbeat failure", "alert_description" : "The device is not sending heartbeats", "configuration_item" : "neglectedmouse.local", "state_change_date" : "2020-05-23T03:44:14" }
{ "alert_name" : "Heartbeat failure", "alert_description" : "The device is not sending heartbeats", "configuration_item" : "givingpromo.local", "state_change_date" : "2020-05-23T03:44:12" }
...
```



**Obtener los cambios de estado para el monitor ``Heartbeat Monitor`` para el servidor ``productivetrue.local``**

```bash
use sysmonitor;

db.configuration_item.aggregate(
    [   { $match: { "name" : "productivetrue.local" } },
        { $unwind: "$monitors" },
        { $match: { "monitors.name" : "Heartbeat Monitor" } },
        { $replaceRoot: { newRoot: "$monitors" } }
    ] 
).pretty()
```

Resultado:

```bash
mongo < query1.js   | more
MongoDB shell version v4.2.8
connecting to: mongodb://127.0.0.1:27017/?compressors=disabled&gssapiServiceName=mongodb
Implicit session: session { "id" : UUID("926a7816-be5c-4ae1-9529-e133c944b37a") }
MongoDB server version: 4.2.8
switched to db sysmonitor
{
        "mon_isntance_id" : 7,
        "name" : "Heartbeat Monitor",
        "description" : "This monitor checks if the device is up",
        "states" : [
                {
                        "state_change_date" : "2020-05-17T15:47:00",
                        "health_State_id" : "Healthy"
                },
                {
                        "state_change_date" : "2020-05-23T03:44:36",
                        "health_State_id" : "Critical"
                },
                {
                        "state_change_date" : "2020-05-23T04:15:57",
                        "health_State_id" : "Healthy"
                }
        ]
}
bye
```



**Obtener datos recolectados por la regla de rendimiento `% Processor Usage` para el CI `productivetrue.local`:**

Para esta consulta, utilizaremos el Aggregation Framework, que nos permite de una forma más cómoda devolver una parte de un documento filtrando a varios niveles de profundidad. Esta sería la consulta:

```javascript
use sysmonitor;

db.configuration_item.aggregate(
    [   { $match: { "name" : "productivetrue.local" } },
        { $unwind: "$performance_rules" },
        { $match: { "performance_rules.rule_name" : "% Processor usage" } },
        { $replaceRoot: { newRoot: "$performance_rules" } }
    ] 
).pretty()
```

Y las primeras líneas del resultado:

```bash
❯ mongo < query1.js    
MongoDB shell version v4.2.8
connecting to: mongodb://127.0.0.1:27017/?compressors=disabled&gssapiServiceName=mongodb
Implicit session: session { "id" : UUID("7997b2b2-bf8c-45cb-b517-c8c83dc80d50") }
MongoDB server version: 4.2.8
switched to db sysmonitor
{
        "ruleId" : 23,
        "rule_name" : "% Processor usage",
        "rule_description" : "% Processor usage",
        "data" : [
                {
                        "value" : 21,
                        "date" : NumberLong("1590192000000")
                },
                {
                        "value" : 25,
                        "date" : NumberLong("1590192300000")
                },
                {
                        "value" : 20,
                        "date" : NumberLong("1590192600000")
                },
                {
                        "value" : 24,
                        "date" : NumberLong("1590192900000")
                },
                {
                        "value" : 24,
                        "date" : NumberLong("1590193200000")
                },
                ....
```



## NEO4J

En este apartado realiza la adaptación del esquema relacional a una base de datos de grafos. Para ello, se hace uso de la máquina NOSQL-029-1, donde se ha instalado NEO4J con la versión 3.3.0. Siguiendo este objetivo, primero se discute cómo adaptar la base de datos relacional a la base de datos de grafos, y más adelante se realiza la implantación del modelo en NEO4J. Por último, se comprueba la correcta implementación a partir de las consultas citadas anteriormente.

### Aproximación de BDR a BDG

En primer lugar, como la base de datos de grafos (BDG) es creada a partir de una base de datos relacional (BDR), se recuerda que la base de datos relacional es la siguiente:

![esquema](./images/esquema.png)

Si se analiza con detenimiento el esquema relacional, se observa que no hay tablas de unión, por lo que cada tabla de la base de datos relacional puede corresponderse con una tabla en la base de datos de grafos.

Sin embargo, en la BDR se observa que existen tablas que asocian un ID con una descripción, como por ejemplo Alert_State o Health_State. Por tanto, se plantea una reducción, de forma que en los nodos del grafo se informen directamente los nombres en vez de un ID asociado a otra tabla. En el caso de grafos, esta reducción es especialmente interesante ya que las consultas se realizan sobre caminos (paths), y lo más común es que mediante un único camino no se pueda obtener tal descripción, sobre todo en consultas complejas. 

Por tanto, una vez se comprende la BDR, se llega a la conclusión de eliminar las tablas Alert_State y Health_State, y en las tablas Alert_Instance y Monitor_Instance_State, uno de sus campos, en vez de ser un ID asociado a otra tabla será directamente un nombre o descripción.  Para las demás tablas de la BDR, se observa que cada tabla se corresponde con un nodo del grafo, y que las relaciones entre tablas serán relaciones entre los nodos de la BDG.

### Creación de la base de datos de grafos

Como primer paso, en la carpeta `./neo4j-community-3.3.0/data/database/` se añade una carpeta con el nombre de la base de datos, en este caso **sysmonitor.db**:

`mkdir /root/neo4j-community-3.3.0/data/databases/sysmonitor.db`

Una vez creada la carpeta, se edita el fichero `/root/neo4j-community-3.3.0/conf/neo4j.conf` y se realiza el siguiente cambio:

`dbms.active_database=sysmonitor.db`

Tras esto, se inicia NEO4J:

`./neo4j-community-3.3.0/bin/neo4j start`

Una vez iniciado, se puede observar que la base de datos activa se corresponde con la que acabamos de crear:

![baseDeDatos](./images/neo4j/baseDeDatos.png)



#### Creación de los nodos de la BDG

Como el modelo se ha creado a partir de una BDR, se descargan los datos correspondientes a las tablas en formato CSV, de cara a importarlos a NEO4J. Tras esto, en la carpeta `./neo4j-community-3.3.0/import` se crea una carpeta llamada `datosSysmonitor`, donde se guardan todos los archivos CSV que contienen la información de tablas de la BDR.

Una vez se puede acceder a la información del modelo relacional, se procede a crear todos los nodos:

*Configuration item*: El nodo se llama **Conf_Item**, y se crea de la siguiente forma:

`LOAD CSV WITH HEADERS FROM "file:///datosSysmonitor/ConfigurationItem.csv" AS row CREATE (n:Conf_Item)` 
`SET` 
`n.ci_id = toInteger(row.ci_id),`
`n.name = row.name;`

Como la lectura de un archivo CSV en NEO4J considera todos los campos como caracteres, en caso de que el campo no sea un caracter ha de indicarse, como ocurre con los IDs.

*Configuration item attributes:* El nodo se llama **CI_Attributes**, y se genera como sigue:

`LOAD CSV WITH HEADERS FROM "file:///datosSysmonitor/ci_Attributes.csv" AS row CREATE (n:CI_Attributes)` 
`SET` 
`n.ci_id = toInteger(row.ci_id),`
`n.att_name = row.att_name,`
`n.att_value = row.att_value;`

*Performance rule*: El nodo se llama **Performance_Rule**, y se crea mediante el siguiente comando:

`LOAD CSV WITH HEADERS FROM "file:///datosSysmonitor/Performance_Rule.csv" AS row CREATE (n:Performance_Rule)` 
`SET` 
`n.ruleId = toInteger(row.ruleId),`
`n.rule_name = row.rule_name,`
`n.rule_description = row.rule_description;`

*Performance rule instance*: El nodo se llama **Perf_Rule_Instance**, y se genera mediante:

`LOAD CSV WITH HEADERS FROM "file:///datosSysmonitor/Performance_Rule_Instance.csv" AS row CREATE (n:Perf_Rule_Instance)` 
`SET` 
`n.ci_id = toInteger(row.ci_id),`
`n.per_ruleId = toInteger(row.per_ruleId),`
`n.instance_id = toInteger(row.instance_id);`

*Performance rule data*: El nodo se llama **Perf_Rule_Data**, y se crea como sigue:

`LOAD CSV WITH HEADERS FROM "file:///datosSysmonitor/Perf_Rule_Data.csv" AS row CREATE (n:Perf_Rule_Data)` 
`SET` 
`n.date = row.date,`
`n.perf_rule_instId = toInteger(row.perf_rule_instId),`
`n.rule_data_id = toInteger(row.rule_data_id),`
`n.value = toInteger(row.value);`

*Monitor:* El nodo también se llama **Monitor,** y es creado mediante la siguiente ejecución:

`LOAD CSV WITH HEADERS FROM "file:///datosSysmonitor/Monitor.csv" AS row CREATE (n:Monitor)` 
`SET` 
`n.name = row.name,`
`n.description = row.description,`
`n.monitor_id = toInteger(row.monitor_id),`
`n.alert_description = row.alert_description,`
`n.alert_name = row.alert_name;`

*Monitor parameters*: El nodo se llama **Monitor_Parameter**, y se genera mediante:

`LOAD CSV WITH HEADERS FROM "file:///datosSysmonitor/Monitor_Parameter.csv" AS row CREATE (n:Monitor_Parameter)` 
`SET` 
`n.name = row.name,`
`n.monitor_id = toInteger(row.monitor_id),`
`n.value = toInteger(row.value),`
`n.param_id = toInteger(row.param_id);`

*Monitor instance*: El nodo se llama **Monitor_Instance**, y se crea mediante:

`LOAD CSV WITH HEADERS FROM "file:///datosSysmonitor/Monitor_Instance.csv" AS row CREATE (n:Monitor_Instance)` 
`SET`
`n.ci_id = toInteger(row.ci_id),`
`n.monitor_id = toInteger(row.monitor_id),`
`n.mon_isntance_id = toInteger(row.mon_isntance_id);`

*Monitor instance state:* A partir de esta tabla se genera el nodo **Monitor_Instance_State**, que ha de crearse de una forma diferente a los anteriores, ya que debe integrar datos de dos fuentes diferentes. Esto se puede realizar de diferentes formas, pero en este caso la resolución ha sido la siguiente:

- Se genera un nodo llamado **Health_State** con los datos de la tabla Health state:

`LOAD CSV WITH HEADERS FROM "file:///datosSysmonitor/Health_State.csv" AS row CREATE (n:Health_State)` 
`SET` 
`n.state_name = row.state_name,`
`n.state_id = toInteger(row.state_id);`

- Se crea el nodo Monitor_Instance_State, equivalente a la tabla relacional Monitor Instance State, donde se sustituye el ID del estado de salud por la descripción gracias al nodo creado anteriormente:

`LOAD CSV WITH HEADERS FROM "file:///datosSysmonitor/Monitor_Instance_State.csv" AS row` 
`MERGE (healthState:Health_State {state_id: toInteger(row.health_State_id)})`
`CREATE (n:Monitor_Instance_State)` 
`SET` 
`n.monitor_instance_state_id = toInteger(row.monitor_instance_state_id),`
`n.state_change_date = row.state_change_date,`
`n.mon_isntance_id = toInteger(row.mon_isntance_id),`
`n.health_state_name = healthState.state_name;`

- Se elimina el nodo Health_State:

`MATCH (n:Health_State) delete n`

*Alert instance*:  A partir de esta tabla se genera el nodo **Alert_Instance**. Este nodo tiene el mismo comportamiento que el anterior, y su creación se ha realizado de la siguiente forma:

- Se genera un nodo llamado **Alert_State**, con los datos de la tabla Alert state:

`LOAD CSV WITH HEADERS FROM "file:///datosSysmonitor/Alert_State.csv" AS row CREATE (n:Alert_State)` 
`SET` 
`n.state_name = row.state_name,`
`n.state_id = toInteger(row.state_id);`

- Una vez generado el nodo anterior, se utiliza para la creación del nodo Alert_Instance, donde en vez de informar el ID del estado de la alerta, se informa la descripción directamente de la siguiente forma:

`LOAD CSV WITH HEADERS FROM "file:///datosSysmonitor/Alert_Instance.csv" AS row` 
`MERGE (alertState:Alert_State {state_id: toInteger(row.alert_State_id)})`
`CREATE (n:Alert_Instance)` 
`SET` 
`n.severity = toInteger(row.severity),`
`n.alert_state_name = alertState.state_name,`
`n.state_change_date = row.state_change_date,`
`n.priority = toInteger(row.priority),`
`n.mon_isntance_id = toInteger(row.mon_isntance_id),`
`n.alert_instance_id = toInteger(row.alert_instance_id);`

- Por último, se elimina el nodo Alert_State:

`MATCH (n:Alert_State) delete n`

Tras aplicar estos comandos, se han generado todos los nodos de la base de datos con sus respectivas propiedades.

#### Creación de relaciones entre nodos

De cara a crear las relaciones entre nodos, se utilizan los mismos campos del esquema relacional, de forma que si coinciden las claves principal y foránea, se crea una relación entre los dos nodos. Lo primero que se puede observar en el esquema relacional es que todas las relaciones son 1:n. De cara a crear las relaciones entre nodos, se toman los datos del nodo asociados al cardinal n, y en caso de coincidir las claves se genera la relación.

Por ejemplo, si se pretende crear la relación entre **Conf_Item** y sus atributos (**CI_Attributes**), se toman todos los datos de CI_Attributes, y se genera una relación en caso de que el campo **ci_id** coincida en ambos nodos.

Por tanto, la creación de todas las relaciones ha sido de la siguiente forma:

*RULE_EXECUTED_IN:* Relaciona los nodos **Performance_Rule** y **Perf_Rule_Instance**:

`LOAD CSV WITH HEADERS FROM "file:///datosSysmonitor/Performance_Rule_Instance.csv" AS row`
`MATCH (perfRule:Performance_Rule {ruleId: toInteger(row.per_ruleId)})`
`MATCH (perfRuleInst:Perf_Rule_Instance {per_ruleId: toInteger(row.per_ruleId)})`
`MERGE (perfRule)-[:RULE_EXECUTED_IN]->(perfRuleInst);`

*RULE_INS_CHANGE_LOG*: Relaciona los nodos **Perf_Rule_Instance** y **Perf_Rule_Data**:

`LOAD CSV WITH HEADERS FROM "file:///datosSysmonitor/Perf_Rule_Data.csv" AS row`
`MATCH (perfRuleInst:Perf_Rule_Instance {instance_id: toInteger(row.perf_rule_instId)})`
`MATCH (perfRuleData:Perf_Rule_Data {perf_rule_instId: toInteger(row.perf_rule_instId)})`
`MERGE (perfRuleInst)-[:RULE_INS_CHANGE_LOG]->(perfRuleData);`

*CI_MEASURED_BY*: Relaciona los nodos **Conf_Item** y **Perf_Rule_Instance**:

`LOAD CSV WITH HEADERS FROM "file:///datosSysmonitor/Performance_Rule_Instance.csv" AS row`
`MATCH (confItem:Conf_Item {ci_id: toInteger(row.ci_id)})`
`MATCH (perfRuleInst:Perf_Rule_Instance {ci_id: toInteger(row.ci_id)})`
`MERGE (confItem)-[:CI_MEASURED_BY]->(perfRuleInst);`

*CI_CONTAINS*: Relaciona los nodos **Conf_Item** y **CI_Attributes**:

`LOAD CSV WITH HEADERS FROM "file:///datosSysmonitor/ci_Attributes.csv" AS row`
`MATCH (confItem:Conf_Item {ci_id: toInteger(row.ci_id)})`
`MATCH (ciAttrib:CI_Attributes {ci_id: toInteger(row.ci_id)})`
`MERGE (confItem)-[:CI_CONTAINS]->(ciAttrib);`

*MONITOR_CONTAINS*: Relaciona los nodos **Monitor** y **Monitor_Parameter**:

`LOAD CSV WITH HEADERS FROM "file:///datosSysmonitor/Monitor_Parameter.csv" AS row`
`MATCH (Monitor:Monitor {monitor_id: toInteger(row.monitor_id)})`
`MATCH (monitorParam:Monitor_Parameter {monitor_id: toInteger(row.monitor_id)})`
`MERGE (Monitor)-[:MONITOR_CONTAINS]->(monitorParam);`

*CI_MONITORED_BY*: Relaciona los nodos **Conf_Item** y **Monitor_Instance**:

`LOAD CSV WITH HEADERS FROM "file:///datosSysmonitor/Monitor_Instance.csv" AS row`
`MATCH (confItem:Conf_Item {ci_id: toInteger(row.ci_id)})`
`MATCH (monitorInstance:Monitor_Instance {ci_id: toInteger(row.ci_id)})`
`MERGE (confItem)-[:CI_MONITORED_BY]->(monitorInstance);`

*MONITOR_INSTANTIATED_BY:* Relaciona los nodos **Monitor** y **Monitor_Instance**:

`LOAD CSV WITH HEADERS FROM "file:///datosSysmonitor/Monitor_Instance.csv" AS row`
`MATCH (monitor:Monitor {monitor_id: toInteger(row.monitor_id)})`
`MATCH (monitorInstance:Monitor_Instance {monitor_id: toInteger(row.monitor_id)})`
`MERGE (monitor)-[:MONITOR_INSTANTIATED_BY]->(monitorInstance);`

*WITH_ALERT*: Relaciona los nodos **Monitor_Instance** y **Alert_Instance**:

`LOAD CSV WITH HEADERS FROM "file:///datosSysmonitor/Alert_Instance.csv" AS row`
`MATCH (monitorInstance:Monitor_Instance {mon_isntance_id: toInteger(row.mon_isntance_id)})`
`MATCH (alertInstance:Alert_Instance {mon_isntance_id: toInteger(row.mon_isntance_id)})`
`MERGE (monitorInstance)-[:WITH_ALERT]->(alertInstance);`

*WITH_STATE*: Relaciona los nodos **Monitor_Instance** y **Monitor_Instance_State:**

`LOAD CSV WITH HEADERS FROM "file:///datosSysmonitor/Monitor_Instance_State.csv" AS row`
`MATCH (monitorInstance:Monitor_Instance {mon_isntance_id: toInteger(row.mon_isntance_id)})`
`MATCH (monInstanceState:Monitor_Instance_State {mon_isntance_id: toInteger(row.mon_isntance_id)})`
`MERGE (monitorInstance)-[:WITH_STATE]->(monInstanceState);`

Tras generar todas las relaciones entre nodos, la base de datos se puede visualizar utilizando el comando `call db.schema`, y al ejecutarlo se observa el siguiente diagrama:

![esquemaBDG](./images/neo4j/esquemaBDG.png)

#### Creación de restricciones

En caso de no añadir nada más al modelo, nada impide que existan dos nodos diferentes con exactamente las mismas propiedades. Para evitar duplicados cuando sea necesario, se han de añadir restricciones en la creación de nuevos nodos. Los nodos que han de tener la restricción de unicidad son:

*Performance_Rule:* La restricción de unicidad se realiza como sigue:

`CREATE CONSTRAINT ON (n:Performance_Rule) ASSERT n.ruleId IS UNIQUE`

*Perf_Rule_Data*: La restricción de unicidad se alcanza mediante:

`CREATE CONSTRAINT ON (n:Perf_Rule_Data) ASSERT n.rule_data_id IS UNIQUE`

*Perf_Rule_Instance:* Se limita la creación de nodos duplicados con el comando:

`CREATE CONSTRAINT ON (n:Perf_Rule_Instance) ASSERT n.instance_id IS UNIQUE`

*Conf_Item:* La restricción de unicidad se realiza con:

`CREATE CONSTRAINT ON (n:Conf_Item) ASSERT n.ci_id IS UNIQUE`

*Monitor:* La unicidad entre nodos se alcanza mediante:

`CREATE CONSTRAINT ON (n:Monitor) ASSERT n.monitor_id IS UNIQUE`

*Monitor_Instance:* La restricción de nodos duplicados se realiza de la forma:

`CREATE CONSTRAINT ON (n:Monitor_Instance) ASSERT n.mon_isntance_id IS UNIQUE`

*Alert_Instance*: Se limita la creación de nodos mediante el siguiente comando:

`CREATE CONSTRAINT ON (n:Alert_Instance) ASSERT n.alert_instance_id IS UNIQUE`

Las demás restricciones a crear contienen varios campos a definir como únicos, como es el caso de *Monitor_Parameter*. Para generar una restricción de unicidad con múltiples propiedades, se necesita la versión Enterprise, y tal restricción se realizaría como sigue:

`CREATE CONSTRAINT Monitor_Parameter_Constraint ON (n:Monitor_Parameter) ASSERT (n.monitor_id, n.param_id) IS NODE KEY`

También existe la opción de crear una nueva propiedad mediante la concatenación de las propiedades únicas, y crear la restricción de unicidad en esta nueva propiedad. En nuestro caso, como en los nodos restantes el hecho de tener duplicados no afecta al correcto funcionamiento de la base de datos, no se ha realizado este método.

### Consultas realizadas

Se han realizado distintas consultas para comprobar el correcto funcionamiento de la base de datos. La obtención de datos de las consultas en este apartado se ha comprobado que es correcta realizando esa misma consulta en la BDR.

Las primeras consultas se realizan para comprobar el número de nodos y relaciones:

![nodos](./images/neo4j/nodos.png)

![relaciones](./images/neo4j/relaciones.png)



- Se consultan todos los *Configuration item* cuyo tipo de dispositivo es *server*  mediante el siguiente comando:

`MATCH (n)-[:CI_CONTAINS]->(atr:CI_Attributes) where atr.att_name = "device_type" and atr.att_value = "server"  return n.ci_id, n.name`

El resultado de esta consulta en NEO4J es:

![consulta1](./images/neo4j/consulta1.png)

Se comprueba que se ha realizado correctamente la consulta comprobando el resultado con el de la BDR:

![consulta1SQL](./images/neo4j/consulta1SQL.png)

- Se  consultan todos los *Monitor instances* para el servidor *productivetrue.local:*

`MATCH (atr:CI_Attributes)<-[:CI_CONTAINS]-(ci:Conf_Item)-[:CI_MONITORED_BY]->(mi:Monitor_Instance)<-[:MONITOR_INSTANTIATED_BY]-(mon:Monitor) WHERE atr.att_name = "device_type" AND atr.att_value = "server" AND ci.name = "productivetrue.local" return mon.name`

El resultado de esta consulta en NEO4J es:

![consulta2](./images/neo4j/consulta2.png)

Se comprueba que el resultado es correcto realizando la misma consulta en la base de datos relacional:

![consulta2SQL](./images/neo4j/consulta2SQL.png)



- Se consultan todos los cambios de estado para *Heartbeat monitor* en el servidor *productivetrue.local*:

`MATCH (atr:CI_Attributes)<-[:CI_CONTAINS]-(ci:Conf_Item)-[:CI_MONITORED_BY]->(mi:Monitor_Instance)-[:WITH_STATE]->(mis:Monitor_Instance_State)`
`match (mi)<-[:MONITOR_INSTANTIATED_BY]-(mon:Monitor)`
`WHERE atr.att_name = "device_type"   AND ci.name = "productivetrue.local" AND mon.name = "Heartbeat Monitor"`
`return mon.name, ci.name, mis.state_name, mis.state_change_date`

El resultado de esta consulta en NEO4J es:

![consulta3](./images/neo4j/consulta3.png)

Si se realiza una consulta similar en la BDR, se obtiene el mismo resultado:

![consulta3SQL](./images/neo4j/consulta3SQL.png)

- Se consultan todas las *Performance rule* disponibles para el servidor *productivetrue.local:*

`MATCH (atr:CI_Attributes)<-[:CI_CONTAINS]-(ci:Conf_Item)-[:CI_MEASURED_BY]->(rins:Perf_Rule_Instance)<-[:RULE_EXECUTED_IN]-(prule:Performance_Rule) WHERE ci.name = "productivetrue.local" AND atr.att_name = "device_type" return prule.rule_name`

El resultado de esta consulta en NEO4J es:

![consulta4](./images/neo4j/consulta4.png)

Se comprueba que el resultado es correcto mediante la misma consulta en la BDR:

![consulta4SQL](./images/neo4j/consulta4SQL.png)

- Se obtiene el %Procesador usado para el servidor *productivetrue.local* entre dos fechas:

Respecto a esta consulta, debido a que la versión de NEO4J instalada es la 3.3.0, no incluye el paquete APOC (**A**wesome **P**rocedures **o**n **C**ypher). En este paquete se añade el tratamiento de fechas, por lo que al no estar disponible, no es posible realizar el tratamiento pedido en la consulta. Además, investigando se ha descubierto que NEO4J no contempla la sentencia BETWEEN, por lo que esta consulta no es óptima. Como aproximación, se realiza la siguiente consulta:

Se obtiene el %Procesador usado para el servidor *productivetrue.local* en un día determinado: Para realizar esta consulta, la fecha se trata como un String, y el comando que la ejecuta es:

`MATCH (atr:CI_Attributes)<-[:CI_CONTAINS]-(ci:Conf_Item)-[:CI_MEASURED_BY]->(rins:Perf_Rule_Instance)-[:RULE_INS_CHANGE_LOG]->(pdata:Perf_Rule_Data) MATCH (rins)<-[:RULE_EXECUTED_IN]-(rule:Performance_Rule) WHERE rule.rule_name = "% Processor usage" and atr.att_name = "device_type" and pdata.date CONTAINS  "2020-05-23" return ci.name, rule.rule_name, pdata.date, pdata.value order by pdata.date`

Se puede observar el resultado de la consulta en NEO4J:

![consulta5](./images/neo4j/consulta5.png)

Y además, se comprueba que la consulta se ha realizado correctamente realizando una equivalente en la BDR:

![consulta5SQL](./images/neo4j/consulta5SQL.png)
