const express = require("express");
const db = require("../config/db");
const { verifyToken } = require("../middleware/auth");

const router = express.Router();

// Add Donation (restaurant only)
router.post("/", verifyToken, (req, res) => {
    if (req.user.role !== "restaurant") {
        return res.status(403).json({ message: "Only restaurants can add donations" });
    }

    const { restaurantName, foodType, quantity, expiryTime } = req.body;

    const sql = `
        INSERT INTO food_donations
        (user_id, restaurant_name, food_type, quantity, expiry_time)
        VALUES (?, ?, ?, ?, ?)
    `;

    db.query(sql, [req.user.id, restaurantName, foodType, quantity, expiryTime],
        (err, result) => {
            if (err) return res.status(500).send(err);
            res.json({ message: "Donation added successfully" });
        });
});

// Get All Donations
router.get("/", verifyToken, (req, res) => {
    // Auto-expire check
    const expireQuery = `
        UPDATE food_donations
        SET status = 'Expired'
        WHERE expiry_time < NOW()
        AND status = 'Available'
    `;
    db.query(expireQuery);

    db.query("SELECT * FROM food_donations ORDER BY created_at DESC",
        (err, results) => {
            if (err) return res.status(500).send(err);
            res.json(results);
        });
});

// Claim Donation (NGO only)
router.put("/:id/claim", verifyToken, (req, res) => {
    if (req.user.role !== "ngo") {
        return res.status(403).json({ message: "Only NGOs can claim donations" });
    }

    const id = req.params.id;

    const sql = `
        UPDATE food_donations
        SET status = 'Claimed'
        WHERE id = ?
        AND status = 'Available'
    `;

    db.query(sql, [id], (err, result) => {
        if (err) return res.status(500).send(err);

        if (result.affectedRows === 0) {
            return res.status(400).json({ message: "Already claimed or expired" });
        }

        res.json({ message: "Donation claimed successfully" });
    });
});

module.exports = router;
