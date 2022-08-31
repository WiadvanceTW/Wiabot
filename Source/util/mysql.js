const mysql = require('mysql')

const config = {
    host: process.env.MysqlHost,
    user: process.env.MysqlUsername,
    password: process.env.MysqlPassword,
    database: process.env.MysqlDatabase,
    port: process.env.MysqlPort,
    waitForConnections : true
};

const createSystemLogSchema = async () => {
    return new Promise((resolve, reject) => {
        process.mysql.query(
            "CREATE TABLE system_log (\
                id int(11) NOT NULL AUTO_INCREMENT COMMENT 'Sequence number',\
                level varchar(20) NOT NULL COMMENT 'Log level',\
                data varchar(500) DEFAULT '' COMMENT 'Log data',\
                error_message varchar(500) DEFAULT '' COMMENT 'Error message',\
                func_name varchar(100) DEFAULT '' COMMENT 'Function name',\
                create_time timestamp NOT NULL COMMENT 'Create time',\
                PRIMARY KEY (`id`)\
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8;", (err, result) => {
            if(err) {
                reject(err)
            }  else {
                resolve(result)
            }
        })
    })    
}

const createTeamsSchema = async () => {
    return new Promise((resolve, reject) => {
        process.mysql.query(
            "CREATE TABLE teams (\
                id int(11) NOT NULL AUTO_INCREMENT COMMENT 'Sequence number',\
                member_id varchar(500) NOT NULL COMMENT 'Teams member id',\
                conversation_id varchar(500) NOT NULL COMMENT 'Teams conversation id',\
                name varchar(100) DEFAULT '' COMMENT 'Teams user name',\
                email varchar(100) NOT NULL COMMENT 'Teams user email',\
                create_time timestamp DEFAULT NULL COMMENT 'Create time',\
                PRIMARY KEY (id)\
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8", (err, result) => {
            if(err) {
                reject(err)
            }  else {
                resolve(result)
            }
        })
    })    
}

const checkTableExist = async (tableName) => {
    return new Promise((resolve, reject) => {
        process.mysql.query('SELECT count(*) AS count FROM information_schema.TABLES WHERE TABLE_NAME = ?', [tableName] , (err, result) => {
            if(err) {
                reject(err)
            }  else {
                resolve(result)
            }
        })
    })
}

const init = async () => {
    const connection = mysql.createPool(config)
    process.mysql = connection
    try {
        teamsTableName =  await checkTableExist('teams')
        if(teamsTableName[0].count == 0) {
            await createTeamsSchema()
        }
        systemLogTableName =  await checkTableExist('system_log')
        if(systemLogTableName[0].count == 0) {
            await createSystemLogSchema()
        }
    } catch (e) {
        console.log(e.message)
    }
}

const getTeamsMemberInfo = async function getTeamsMemberInfo(id) {
    return new Promise((resolve, reject) => {
        process.mysql.query('select * from teams where member_id = ?', [id] , (err, result) => {
            if(err) {
                reject(err)
            }  else {
                resolve(result)
            }
        })
    })
}

const getUserInfo = async function getTeamsMemberInfo(email) {
    return new Promise((resolve, reject) => {
        process.mysql.query('select * from teams where email = ?', [email] , (err, result) => {
            if(err) {
                reject(err)
            }  else {
                resolve(result)
            }
        })
    })
}

const createTeamsMemberInfo = async function createTeamsMemberInfo(data) {
    return new Promise((resolve, reject) => {
        process.mysql.query('INSERT INTO teams (member_id, conversation_id, name, email, create_time) VALUES (?, ?, ?, ?, SYSDATE())',  [data["member_id"], data["conversation_id"], data["name"], data["email"], 0, 0], async function (err, results, fields) {
            if(err) {
                reject(err)
            }  else {
                resolve(results) 
            }
        })
    })
}


const addLog = async function addLog(data) {
    return new Promise((resolve, reject) => {
        process.mysql.query('INSERT INTO system_log (level, data, error_message, func_name, create_time) VALUES (?, ?, ?, ?, SYSDATE())',  [data["level"], data["data"], data["error_message"], data["func_name"], 'sysdate()'], async function (err, results, fields) {
            if(err) {
                reject(err)
            }  else {
                resolve(results)
            }  
        })
    }) 
}

module.exports = {
    init: init,
    getTeamsMemberInfo: getTeamsMemberInfo,
    createTeamsMemberInfo: createTeamsMemberInfo,
    getUserInfo: getUserInfo,
    addLog: addLog  
}