const express   = require("express");
const bcrypt    = require("bcryptjs");
const jwt       = require("jsonwebtoken");
const oracledb  = require("oracledb");
const db        = require("../config/db");
const { JWT_SECRET } = require("../middleware/auth");

const router = express.Router();

// Register
router.post("/register", async (req, res) => {
    const { username, password, role, restaurantName } = req.body;

    if (!username || !password || !role) {
        return res.status(400).json({ message: "All fields are required" });
    }
    if (!["restaurant", "ngo"].includes(role)) {
        return res.status(400).json({ message: "Role must be 'restaurant' or 'ngo'" });
    }
    if (role === "restaurant" && !restaurantName) {
        return res.status(400).json({ message: "Restaurant name is required for restaurant accounts" });
    }

    try {
        const hashedPassword = await bcrypt.hash(password, 10);

        const sql = `
            INSERT INTO users (username, password, role, restaurant_name)
            VALUES (:username, :password, :role, :restaurant_name)
            RETURNING id INTO :new_id
        `;
        const binds = {
            username,
            password:        hashedPassword,
            role,
            restaurant_name: restaurantName || null,
            new_id:          { dir: oracledb.BIND_OUT, type: oracledb.NUMBER }
        };

        const result = await db.execute(sql, binds);
        const newId  = result.outBinds.new_id[0];

        const token = jwt.sign(
            { id: newId, username, role, restaurantName: restaurantName || null },
            JWT_SECRET,
            { expiresIn: "24h" }
        );

        res.json({ token, role, restaurantName: restaurantName || null });
    } catch (err) {
        if (err.errorNum === 1) {
            return res.status(409).json({ message: "Username already exists" });
        }
        console.error(err);
        res.status(500).json({ message: "Server error" });
    }
});

// Login
router.post("/login", async (req, res) => {
    const { username, password } = req.body;

    if (!username || !password) {
        return res.status(400).json({ message: "All fields are required" });
    }

    try {
        const sql    = `SELECT id, username, password, role, restaurant_name FROM users WHERE username = :username`;
        const result = await db.execute(sql, { username });

        if (result.rows.length === 0) {
            return res.status(401).json({ message: "Invalid username or password" });
        }

        const user    = result.rows[0];
        const isMatch = await bcrypt.compare(password, user.PASSWORD);

        if (!isMatch) {
            return res.status(401).json({ message: "Invalid username or password" });
        }

        const token = jwt.sign(
            { id: user.ID, username: user.USERNAME, role: user.ROLE, restaurantName: user.RESTAURANT_NAME || null },
            JWT_SECRET,
            { expiresIn: "24h" }
        );

        res.json({ token, role: user.ROLE, restaurantName: user.RESTAURANT_NAME || null });
    } catch (err) {
        console.error(err);
        res.status(500).json({ message: "Server error" });
    }
});

module.exports = router;
