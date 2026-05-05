require("dotenv").config();
const oracledb = require("oracledb");

oracledb.outFormat = oracledb.OUT_FORMAT_OBJECT;

let pool;

async function initialize() {
    pool = await oracledb.createPool({
        user:          process.env.DB_USER,
        password:      process.env.DB_PASSWORD,
        connectString: process.env.DB_CONNECT_STRING,
        poolMax:       parseInt(process.env.DB_CONNECTION_LIMIT) || 10,
        poolMin:       1,
        poolIncrement: 1
    });
    console.log("Connected to Oracle DB");
}

async function execute(sql, binds = {}, opts = {}) {
    const conn = await pool.getConnection();
    try {
        return await conn.execute(sql, binds, { autoCommit: true, ...opts });
    } finally {
        await conn.close();
    }
}

async function getConnection() {
    return pool.getConnection();
}

// Oracle returns column names in uppercase — convert to lowercase for the frontend
function mapRows(rows) {
    if (!Array.isArray(rows)) return [];
    return rows.map(row =>
        Object.fromEntries(Object.entries(row).map(([k, v]) => [k.toLowerCase(), v]))
    );
}

module.exports = { initialize, execute, getConnection, mapRows };
