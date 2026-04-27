const express = require("express");
const db = require("../config/db");
const { verifyToken } = require("../middleware/auth");

const router = express.Router();

// Add Donation (restaurant only)
router.post("/", verifyToken, (req, res) => {
    if (req.user.role !== "restaurant") {
        return res.status(403).json({ message: "Only restaurants can add donations" });
    }

    const { foodType, quantity, expiryTime, pickupNotes } = req.body;

    const sql = `
        INSERT INTO food_donations
        (user_id, food_type, quantity, expiry_time, pickup_notes)
        VALUES (?, ?, ?, ?, ?)
    `;

    db.query(sql, [req.user.id, foodType, quantity, expiryTime, pickupNotes || null],
        (err, result) => {
            if (err) return res.status(500).send(err);
            res.json({ message: "Donation added successfully" });
        });
});

// Get Donations — restaurants see only their own; NGOs see all
router.get("/", verifyToken, (req, res) => {
    const expireQuery = `
        UPDATE food_donations
        SET status = 'Expired'
        WHERE expiry_time < NOW()
        AND status = 'Available'
    `;
    db.query(expireQuery);

    const isRestaurant = req.user.role === "restaurant";
    const sql = `
        SELECT
            fd.id,
            u.restaurant_name,
            fd.food_type,
            fd.quantity,
            fd.expiry_time,
            fd.status,
            fd.pickup_notes,
            fd.created_at
        FROM food_donations fd
        INNER JOIN users u ON fd.user_id = u.id
        ${isRestaurant ? "WHERE fd.user_id = ?" : ""}
        ORDER BY fd.created_at DESC
    `;
    const params = isRestaurant ? [req.user.id] : [];

    db.query(sql, params, (err, results) => {
        if (err) return res.status(500).send(err);
        res.json(results);
    });
});

// Claim Donation (NGO only) — uses ClaimDonation stored procedure
router.put("/:id/claim", verifyToken, (req, res) => {
    if (req.user.role !== "ngo") {
        return res.status(403).json({ message: "Only NGOs can claim donations" });
    }

    const donationId = req.params.id;
    const ngoUserId  = req.user.id;

    const sql = `CALL ClaimDonation(?, ?, @success, @message)`;

    db.query(sql, [donationId, ngoUserId], (err) => {
        if (err) return res.status(500).send(err);

        db.query("SELECT @success AS success, @message AS message", (err2, rows) => {
            if (err2) return res.status(500).send(err2);

            const { success, message } = rows[0];
            if (!success) {
                return res.status(400).json({ message });
            }
            res.json({ message });
        });
    });
});

module.exports = router;
