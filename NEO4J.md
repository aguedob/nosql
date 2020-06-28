# Implementación en NEO4J

<!--INTRO DE LOS PASOS QUE SE VAN A REALIZAR Y LA MÁQUINA QUE SE VA A USAR-->

### Aproximación de BDR a BDG

En primer lugar, como la base de datos de grafos (BDG) es creada a partir de una base de datos relacional, se recuerda que la base de datos relacional (BDR) es la siguiente:

<!--IMAGEN-->

Si se analiza con detenimiento el esquema relacional, se observa que no hay tablas de unión, por lo que cada tabla de la base de datos relacional puede corresponderse con una tabla en la base de datos de grafos.

En la BDR, se observa que existen tablas que asocian un ID con una descripción, como por ejemplo Alert_State o Health_State. Se puede plantear una reducción, de forma que en los nodos del grafo se informen directamente los nombres en vez de un ID asociado a otra tabla. En el caso de grafos, esta reducción es interesante ya que las consultas se realizan sobre caminos (paths), y lo más común es que mediante un único camino no se pueda obtener tal descripción, sobre todo en queries complejas. Sin embargo, en este proyecto no se realizará tal simplificación, de cara a que sea más enriquecedor.

Una vez decidido que cada tabla se corresponde con un nodo y que las relaciones entre nodos se corresponden con las relaciones entre tablas, se procede a crear la base de datos de grafos.

### Creación de la base de datos de grafos

Como primer paso, en la carpeta `./neo4j-community-3.3.0/data/database/` se añade una carpeta con el nombre de la base de datos, en este caso **sysmonitor.db**:

`mkdir /root/neo4j-community-3.3.0/data/databases/sysmonitor.db`

Una vez creada la carpeta, se edita el fichero `/root/neo4j-community-3.3.0/conf/neo4j.conf` y se realiza el siguiente cambio:

`dbms.active_database=sysmonitor.db`

Tras esto, se inicia NEO4J:

`./neo4j-community-3.3.0/bin/neo4j start`

Una vez iniciado, se puede observar que la base de datos activa se corresponde con la que acabamos de crear:

<!--`IMAGEN BASE DE DATOS`-->

### Creación de los nodos de la BDG

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

*Monitor instance state:* El nodo se llama **Monitor_Instance_State**, y se crea utilizando el siguiente comando:

`LOAD CSV WITH HEADERS FROM "file:///datosSysmonitor/Monitor_Instance_State.csv" AS row CREATE (n:Monitor_Instance_State)` 
`SET` 
`n.monitor_instance_state_id = toInteger(row.monitor_instance_state_id),`
`n.state_change_date = row.state_change_date,`
`n.mon_isntance_id = toInteger(row.mon_isntance_id),`
`n.health_State_id = toInteger(row.health_State_id);`

*Health state*: El nodo se llama **Health_State**, y se genera mediante:

`LOAD CSV WITH HEADERS FROM "file:///datosSysmonitor/Health_State.csv" AS row CREATE (n:Health_State)` 
`SET` 
`n.state_name = row.state_name,`
`n.state_id = toInteger(row.state_id);`

*Alert instance*: El nodo se llama **Alert_Instance**, y se produce mediante:

`LOAD CSV WITH HEADERS FROM "file:///datosSysmonitor/Alert_Instance.csv" AS row CREATE (n:Alert_Instance)` 
`SET` 
`n.severity = toInteger(row.severity),`
`n.alert_State_id = toInteger(row.alert_State_id),`
`n.state_change_date = row.state_change_date,`
`n.priority = toInteger(row.priority),`
`n.mon_isntance_id = toInteger(row.mon_isntance_id),`
`n.alert_instance_id = toInteger(row.alert_instance_id);`

*Alert state*: El nodo se llama **Alert_State**, y se origina mediante el siguiente código:

`LOAD CSV WITH HEADERS FROM "file:///datosSysmonitor/Alert_State.csv" AS row CREATE (n:Alert_State)` 
`SET` 
`n.state_name = row.state_name,`
`n.state_id = toInteger(row.state_id);`

Tras aplicar estos comandos, se han generado todos los nodos de la base de datos con sus respectivas propiedades.

### Creación de relaciones entre nodos

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

*WITH_ALERT_STATE:* Relaciona los nodos **Alert_State** y **Alert_Instance**:

`LOAD CSV WITH HEADERS FROM "file:///datosSysmonitor/Alert_Instance.csv" AS row`
`MATCH (alertState:Alert_State {state_id: toInteger(row.alert_State_id)})`
`MATCH (alertInstance:Alert_Instance {alert_State_id: toInteger(row.alert_State_id)})`
`MERGE (alertState)-[:WITH_ALERT_STATE]->(alertInstance);`

*WITH_STATE*: Relaciona los nodos **Monitor_Instance** y **Monitor_Instance_State:**

`LOAD CSV WITH HEADERS FROM "file:///datosSysmonitor/Monitor_Instance_State.csv" AS row`
`MATCH (monitorInstance:Monitor_Instance {mon_isntance_id: toInteger(row.mon_isntance_id)})`
`MATCH (monInstanceState:Monitor_Instance_State {mon_isntance_id: toInteger(row.mon_isntance_id)})`
`MERGE (monitorInstance)-[:WITH_STATE]->(monInstanceState);`

*WITH_HEALTH_STATE*: Relaciona los nodos **Health_State** y **Monitor_Instance_State:**

`LOAD CSV WITH HEADERS FROM "file:///datosSysmonitor/Monitor_Instance_State.csv" AS row`
`MATCH (healthState:Health_State {state_id: toInteger(row.health_State_id)})`
`MATCH (monInstanceState:Monitor_Instance_State {health_State_id: toInteger(row.health_State_id)})`
`MERGE (healthState)-[:WITH_HEALTH_STATE]->(monInstanceState);`

Tras generar todas las relaciones entre nodos, la base de datos se puede visualizar utilizando el comando `call db.schema`, y al ejecutarlo se observa el siguiente diagrama:

<!--IMAGEN DEL DIAGRAMA DE GRAFOS--> 

### Creación de restricciones

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

*Alert_State:* La restricción de unicidad se alcanza mediante:

`CREATE CONSTRAINT ON (n:Alert_State) ASSERT n.state_id IS UNIQUE`

Las demás restricciones a crear contienen varios campos a definir como únicos, como es el caso de *Monitor_Parameter*. Para generar una restricción de unicidad con múltiples propiedades, se necesita la versión Enterprise, y tal restricción se realizaría como sigue:

`CREATE CONSTRAINT Monitor_Parameter_Constraint ON (n:Monitor_Parameter) ASSERT (n.monitor_id, n.param_id) IS NODE KEY`

También existe la opción de crear una nueva propiedad mediante la concatenación de las propiedades únicas, y crear la restricción de unicidad en esta nueva propiedad. En nuestro caso, como en los nodos restantes el hecho de tener duplicados no afecta al correcto funcionamiento de la base de datos, no se ha realizado este método.

### Consultas realizadas

Se han realizado distintas consultas para comprobar el correcto funcionamiento de la base de datos. La obtención de datos de las consultas en este apartado se ha comprobado que es correcta realizando esa misma consulta en la BDR.

Las primeras consultas se realizan para comprobar el número de nodos y relaciones:

