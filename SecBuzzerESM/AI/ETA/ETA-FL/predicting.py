import datetime, os, configparser, pickle, pytz

import pandas as pd
import numpy as np

from argparse import ArgumentParser
from elasticsearch import Elasticsearch, helpers


class Main():
  def __init__(self):
    config = configparser.ConfigParser()
    config.read(os.path.dirname(os.path.abspath(__file__))+"/config.ini")
    self.now = datetime.datetime.now(pytz.timezone("Asia/Taipei"))
    # es
    self.es_server = config.get("ES", "es_server")
    self.es_port = eval(config.get("ES", "es_port"))
    # train
    self.preds = eval(config.get("Train", "preds"))
    self.K = eval(config.get("Train", "K"))
    self.N_Class = eval(config.get("Train", "N_Class"))
    self.label_table = eval(config.get("Train", "label_table"))
    self.model_path = os.path.dirname(os.path.abspath(__file__))+"/"+config.get("Train", "model_path")
    # output
    self.mode = eval(config.get("Output", "mode"))
    self.label_msg = eval(config.get("Output", "label_msg"))
    self.proto_table = eval(config.get("Output", "proto_table"))
    self.sig_id = eval(config.get("Output", "sig_id"))

  def queryES(self, es_index, start_time, end_time):
    es = Elasticsearch([{"host":self.es_server, "port":self.es_port}])
    body = {"query":{"bool":{"must":[{"range":{"Timestamp":{"gt":start_time,"lt":end_time}}}]}}}
    res = helpers.scan(client=es, scroll="10m", query=body, index=es_index)
    return res
  
  def toDf(self, res):
    data = list()
    for nf in res:
      tmp = dict()
      tmp["id"] = nf["_id"]
      tmp.update(nf["_source"])
      data.append(tmp)
    df = pd.DataFrame(data)
    return df
  
  def processData(self, df):
    cols_bytes = ["byte_{}".format(i) for i in range(256)]
    df[cols_bytes] = df["Payload BYTE Distribution"].str.split("-", expand=True)
    if os.path.exists(self.model_path+"preds_sel.txt"):
      with open(self.model_path+"preds_sel.txt","r") as text_file:
        preds = eval(text_file.read())
    else:
      preds = self.preds+cols_bytes
    try:
      df_fin = df[preds]
      df_id = df[["id", "Timestamp", "Src IP", "Src Port", "Dst IP", "Dst Port", "Protocol", "nic_name"]]
    except:
      col = ""
      for c in self.preds+cols_bytes+["id", "Timestamp", "Src IP", "Src Port", "Dst IP", "Dst Port", "Protocol", "nic_name"]:
        if c not in df.columns:
          col += ", " + c
      print("error: lost columns {}".format(col))
    return df_fin, df_id
  
  def predict(self, df):
    fs = [f for f in os.listdir(self.model_path) if ".model.pickle.dat" in f]
    predictions = np.zeros([self.K, len(df), self.N_Class])
    for i, f in enumerate(fs):
      m_path = os.path.join(self.model_path, f)
      m = pickle.load(open(m_path, "rb"))
      predictions[i] = m.predict_proba(df.values)
    if self.mode == 0:
      pred = np.argmax(predictions.mean(axis=0), axis=1)
      pred = [self.label_table[x] for x in pred]
    elif self.mode == 1:
      def func(f_list, array):
        tmp = list()
        for f in f_list:
          v = pd.DataFrame(f(array, axis=0), dtype="str", columns=self.label_table.values())
          tmp.append(v)
        pred = "[" + tmp[0]
        for v in tmp[1:]:
          pred += "," + v
        pred += "]"
        return pred
      pred = eval(func([np.min, np.mean, np.max], predictions).to_json(orient="records"))
    return pred

  def toJSON(self, pred, df_fin, df_id):
    df = df_id.copy()
    df.rename(columns={"id":"flow_id", "Timestamp":"log_time", "Src IP":"src_ip", "Src Port":"src_port",
                       "Dst IP":"dest_ip", "Dst Port":"dest_port", "Protocol":"proto", "nic_name":"in_iface"}, inplace=True)
    df["title"] = pred
    df[["src_port", "dest_port"]] = df[["src_port", "dest_port"]].astype("int")
    df["proto"] = df["proto"].apply(lambda x: self.proto_table[x])
    df["timestamp"] = self.now.strftime("%Y-%m-%dT%H:%M:%S.%f+08:00")
    df["ingest_timestamp"] = (self.now - datetime.timedelta(hours=8)).strftime("%Y-%m-%dT%H:%M:%S.%fZ")
    df["reference"] = "0"
    df["module"] = "ETA-MALWARE"
    df["log_type"] = "traffic"
    df["dump_status"] = "0"
    df["user_data1"] = eval(df_fin.to_json(orient="records"))
    if self.mode == 0:
      df["event_type"] = "alert"
      df["severity"] = 2
      df["message"] = df["title"].apply(lambda x: self.label_msg[x])
      df["action"] = "0"
      df["rule_sig_id"] = df["title"].apply(lambda x: self.sig_id[x])
      df["alert_group_id"] = 0
      df["alert"] = df.apply(lambda x: {"category":x["title"], "severity":x["severity"], "signature":x["message"],
                                        "action":x["action"], "signature_id":x["rule_sig_id"], "gid":x["alert_group_id"]}, axis=1)
      df = df[df["title"] != "normal"]
      df.drop(["title", "severity", "message", "action", "rule_sig_id", "alert_group_id"], axis=1, inplace=True)
    elif self.mode == 1:
      pass
    output = eval(df.to_json(orient="records"))
    return output
  
  def toES(self, dic):
    if len(dic) > 0:
      es_idx = datetime.datetime.now().strftime("eta-malware-%Y-%m")
      for d in dic:
        es = Elasticsearch([{"host":self.es_server, "port":self.es_port}])
        es.index(index=es_idx, doc_type="_doc", body=d)
    else:
      pass

if __name__ == "__main__":
  load_main = Main()
  parser = ArgumentParser()
  parser.add_argument("-input", "-mode", help="the source of input data, from csv or es", dest="mode", default="es")
  args = parser.parse_args()
  print("data source:", args.mode)
  if args.mode not in ["csv", "es"]:
    print("error: Please enter right mode, csv or es")
  elif args.mode == "csv":
    df = pd.read_csv("data/sample.csv", dtype="str")
  elif args.mode == "es":
    es_index = "cic-20201119"
    start_time = "2020-11-19T00:00:00.000000+08:00"
    end_time = "2020-11-19T01:00:00.000000+08:00"
    res = load_main.queryES(es_index, start_time, end_time)
    df = load_main.toDf(res)
  if df.shape[0] != 0:
    df_fin, df_id = load_main.processData(df)
    pred = load_main.predict(df_fin)
    output = load_main.toJSON(pred, df_fin, df_id)
    load_main.toES(output)
  else:
    print("msg: There is no data")
