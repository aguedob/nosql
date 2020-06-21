
-- All CIs with device_type 'server'
select * from dbo.ConfigurationItem
inner join dbo.ci_Attributes
on dbo.ConfigurationItem.ci_id = dbo.ci_Attributes.ci_id
and att_name like 'device_type'
and att_value like 'server'

-- All attributes for server 'productivetrue.local'
select * from dbo.ConfigurationItem
left outer join dbo.ci_Attributes
on dbo.ConfigurationItem.ci_id = dbo.ci_Attributes.ci_id
where name='productivetrue.local'
and att_name like 'device_type'
and att_value like 'server'

-- All monitors instanced in server 'productivetrue.local'
select dbo.Monitor.name from dbo.Monitor
inner join dbo.Monitor_Instance
on dbo.Monitor.monitor_id = dbo.Monitor_Instance.monitor_id
inner join dbo.ConfigurationItem
on dbo.Monitor_Instance.ci_id = dbo.ConfigurationItem.ci_id
inner join dbo.ci_Attributes
on dbo.ConfigurationItem.ci_id = dbo.ci_Attributes.ci_id
where dbo.ConfigurationItem.name='productivetrue.local'
and att_name like 'device_type'
and att_value like 'server'


-- All state changes for 'Heartbeat Monitor' in server 'productivetrue.local'
select 
dbo.Monitor.name, 
dbo.ConfigurationItem.name,
dbo.Health_state.state_name,
dbo.Monitor_Instance_State.state_change_date
from dbo.Monitor_Instance_State
inner join dbo.Monitor_Instance
on dbo.Monitor_Instance_State.mon_isntance_id = dbo.Monitor_Instance.mon_isntance_id
inner join dbo.Monitor
on dbo.Monitor.monitor_id = dbo.Monitor_Instance.monitor_id
inner join dbo.ConfigurationItem
on dbo.Monitor_Instance.ci_id = dbo.ConfigurationItem.ci_id
inner join dbo.ci_Attributes
on dbo.ConfigurationItem.ci_id = dbo.ci_Attributes.ci_id
inner join dbo.Health_state
on dbo.Health_state.state_id = dbo.Monitor_Instance_State.health_state_id
where dbo.ConfigurationItem.name='productivetrue.local'
and att_name like 'device_type'
and dbo.Monitor.name like 'Heartbeat Monitor'