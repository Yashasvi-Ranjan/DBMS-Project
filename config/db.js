require("dotenv").config();
const mysql = require("mysql2");

const db = mysql.createPool({
    host: process.env.DB_HOST,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME,
    waitForConnections: true,
    connectionLimit: parseInt(process.env.DB_CONNECTION_LIMIT) || 10
});

db.getConnection((err, connection) => {
    if (err) throw err;
    console.log("Connected to MySQL");
    connection.release();
});

module.exports = db;
