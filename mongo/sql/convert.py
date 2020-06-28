import pandas as pd
ci_df = pd.read_json("Configuration_Item.json")
attributes_df = pd.read_json("Attribute.json")
ci_att_df = pd.merge(ci_df,attributes_df,on="ci_id")
cp=ci_att_df.pivot(index="name", columns="att_name")
cp.columns = ['ci_id','ci_id2','ci_id3','device_type','env','ip_address']
cp.drop(columns=['ci_id2', 'ci_id3'], inplace=True)
cp=cp.reset_index()
cp.set_index('ci_id',inplace=True)
cp.to_csv("CI_Attribute.csv")
