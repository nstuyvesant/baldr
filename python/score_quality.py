from simple_salesforce import Salesforce
import psycopg2
import logging
from logging.handlers import RotatingFileHandler

## config logging
def config_logging(log_name, log_path):
    logger = logging.getLogger(log_name)
    logger.setLevel(logging.DEBUG)
    fh = RotatingFileHandler(log_path, maxBytes=1024 * 1024 * 10, backupCount=1)
    formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
    fh.setFormatter(formatter)
    logger.addHandler(fh)
    return logger

## update the score_quality in the snapshots table
def update_records(score,cloud_id):
    try:
        conn = psycopg2.connect("host='54.145.158.183' dbname='vr' user='postgres' password='mysecret123'")
        cursor = conn.cursor()
        query = "UPDATE snapshots SET score_quality='"+str(score)+"'  WHERE cloud_id = '"+str(cloud_id)+"' and snapshot_date = TIMESTAMP 'yesterday'"
        cursor.execute(query)
        conn.commit()
        global_logger.info("db query result : " + str(cursor.rowcount))
        cursor.close()
    except psycopg2.DatabaseError, e:
        global_logger.info(e)
        if conn:
            con.rollback()

# get the number of cases from SF plus the cases age ( days)
def exec_query(query ,mul ,days):
    sf = Salesforce(username='autoupdate@perfectomobile.com', password='pmintegration',security_token='9MpjGD5iiyJvBH7vi5p9pUUw')
    total = 0
    res = sf.query_all(query)
    for record in res['records']:
        total += mul - record['Age_Custom__c'] * days

    return round(total)

## run the queries on the salesfore db and return result
def run_queries(cloud):
    try:

        defect = "SELECT Age_Custom__c FROM Case WHERE Case.Type = 'Defect' AND Case.CreatedDate >= LAST_N_DAYS:30 AND Case.AppURL__c ='" + cloud + "' "
        defect = exec_query(defect, 15, 0.5)
        global_logger.info("defect " + str(defect))

        service_degradation = "SELECT Age_Custom__c FROM Case WHERE Case.Case_Reason__c = 'Cloud: Service Degradation' AND Case.CreatedDate >= LAST_N_DAYS:30 AND Case.AppURL__c ='" + cloud + "' "
        service_degradation = exec_query(service_degradation, 15, 0.5)
        global_logger.info("service_degradation " + str(service_degradation))

        outage = "SELECT Age_Custom__c FROM Case WHERE Case.Case_Reason__c = 'Cloud: Outage' AND Case.CreatedDate >= LAST_N_DAYS:90 AND Case.AppURL__c ='" + cloud + "' "
        outage = exec_query(outage, 25, 0.16667)
        global_logger.info("outage " + str(outage))

        maintenance = "SELECT Age_Custom__c FROM Case WHERE Case.Case_Reason__c = 'Cloud: Maintenance issue' AND Case.CreatedDate >= LAST_N_DAYS:90 AND Case.AppURL__c ='" + cloud + "'"
        maintenance = exec_query(maintenance, 50, 0.16667)
        global_logger.info("maintenance " + str(maintenance))

        hot_list = "SELECT Age_Custom__c FROM Case WHERE Case.Hot_List__c = 'Hot-R&D' AND Case.CreatedDate >= LAST_N_DAYS:60 AND Case.AppURL__c ='" + cloud + "'"
        hot_list = exec_query(hot_list, 25, 0.25)
        global_logger.info("hot_list " + str(hot_list))

        score = int (100 - round(defect + service_degradation + outage + maintenance + hot_list))
        return score
    except Exception, e:
        global_logger.info(e)
        return None

##MAIN

global_logger = config_logging("salesforce", "/var/log/score_quality.log")

try:
    # loop on the clouds table
    con = psycopg2.connect("host='54.145.158.183' dbname='vr' user='postgres' password='mysecret123'")
    cur = con.cursor()
    cur.execute("select distinct fqdn,id from clouds")
    while True:
        row = cur.fetchone()
        if row == None:
            break
        # get the cloud score
        score =run_queries(row[0])
        # update the score in the snapshot table if score is not null
        if score : update_records(score,row[1])
        global_logger.info( "cloud " + row[0] +" id " + row[1] + " + score : " + str(score))

except psycopg2.DatabaseError, e:
    if con:
        con.rollback()






