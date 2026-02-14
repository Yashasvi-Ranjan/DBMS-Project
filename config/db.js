const mysql = require("mysql2");

const db = mysql.createPool({
    host: "localhost",
    user: "root",
    password: "Sairam@171",
    database: "food_waste_db",
    waitForConnections: true,
    connectionLimit: 10
});

db.getConnection((err, connection) => {
    if (err) throw err;
    console.log("Connected to MySQL");
    connection.release();
});

module.exports = db;
