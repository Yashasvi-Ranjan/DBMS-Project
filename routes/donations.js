const express  = require("express");
const db       = require("../config/db");
const { verifyToken } = require("../middleware/auth");

const router = express.Router();

// Add Donation (restaurant only)
router.post("/", verifyToken, async (req, res) => {
    if (req.user.role !== "restaurant") {
        return res.status(403).json({ message: "Only restaurants can add donations" });
    }

    const { foodType, quantity, expiryTime, pickupNotes } = req.body;

    try {
        const sql = `
            INSERT INTO food_donations (user_id, food_type, quantity, expiry_time, pickup_notes)
            VALUES (:user_id, :food_type, :quantity, :expiry_time, :pickup_notes)
        `;
        await db.execute(sql, {
            user_id:      req.user.id,
            food_type:    foodType,
            quantity:     Number(quantity),
            expiry_time:  new Date(expiryTime),
            pickup_notes: pickupNotes || null
        });

        res.json({ message: "Donation added successfully" });
    } catch (err) {
        if (err.errorNum === 20001 || err.errorNum === 20002) {
            // Extract the message text from Oracle's "ORA-20001: <message>" format
            const match = err.message.match(/ORA-\d+:\s*(.*)/);
            return res.status(400).json({ message: match ? match[1].trim() : err.message });
        }
        console.error(err);
        res.status(500).json({ message: "Server error" });
    }
});

// Get Donations — restaurants see only their own; NGOs see all
router.get("/", verifyToken, async (req, res) => {
    try {
        // Auto-expire overdue donations
        await db.execute(`
            UPDATE food_donations
            SET status = 'Expired'
            WHERE expiry_time < SYSTIMESTAMP
              AND status = 'Available'
        `);

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
            ${isRestaurant ? "WHERE fd.user_id = :user_id" : ""}
            ORDER BY fd.created_at DESC
        `;
        const binds  = isRestaurant ? { user_id: req.user.id } : {};
        const result = await db.execute(sql, binds);

        res.json(db.mapRows(result.rows));
    } catch (err) {
        console.error(err);
        res.status(500).json({ message: "Server error" });
    }
});

// Claim Donation (NGO only)
router.put("/:id/claim", verifyToken, async (req, res) => {
    if (req.user.role !== "ngo") {
        return res.status(403).json({ message: "Only NGOs can claim donations" });
    }

    const donationId = Number(req.params.id);
    const ngoUserId  = req.user.id;
    const conn       = await db.getConnection();

    try {
        const selectResult = await conn.execute(
            `SELECT status FROM food_donations WHERE id = :id FOR UPDATE`,
            { id: donationId },
            { autoCommit: false }
        );

        if (selectResult.rows.length === 0) {
            await conn.rollback();
            return res.status(404).json({ message: "Donation not found" });
        }

        const status = selectResult.rows[0].STATUS;
        if (status !== "Available") {
            await conn.rollback();
            return res.status(400).json({ message: "Donation is already " + status });
        }

        await conn.execute(
            `UPDATE food_donations SET status = 'Claimed' WHERE id = :id`,
            { id: donationId },
            { autoCommit: false }
        );

        await conn.execute(
            `INSERT INTO donation_claims (donation_id, ngo_user_id) VALUES (:donation_id, :ngo_user_id)`,
            { donation_id: donationId, ngo_user_id: ngoUserId },
            { autoCommit: false }
        );

        await conn.execute(
            `INSERT INTO audit_log (action, table_name, record_id, old_value, new_value, performed_by)
             VALUES ('CLAIM', 'food_donations', :record_id, 'Available', 'Claimed', :performed_by)`,
            { record_id: donationId, performed_by: ngoUserId },
            { autoCommit: false }
        );

        await conn.commit();
        res.json({ message: "Donation claimed successfully" });
    } catch (err) {
        await conn.rollback();
        console.error(err);
        res.status(500).json({ message: "Could not complete donation claim" });
    } finally {
        await conn.close();
    }
});

module.exports = router;
