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

// Claim Donation (NGO only)
router.put("/:id/claim", verifyToken, (req, res) => {
    if (req.user.role !== "ngo") {
        return res.status(403).json({ message: "Only NGOs can claim donations" });
    }

    const donationId = req.params.id;
    const ngoUserId  = req.user.id;

    db.getConnection((connErr, connection) => {
        if (connErr) {
            return res.status(500).json({ message: "Database connection failed" });
        }

        const fail = (status, message, err) => {
            connection.rollback(() => {
                connection.release();
                if (err) console.error(err);
                res.status(status).json({ message });
            });
        };

        connection.beginTransaction((txErr) => {
            if (txErr) {
                connection.release();
                return res.status(500).json({ message: "Could not start claim transaction" });
            }

            const selectSql = `
                SELECT status
                FROM food_donations
                WHERE id = ?
                FOR UPDATE
            `;

            connection.query(selectSql, [donationId], (selectErr, rows) => {
                if (selectErr) {
                    return fail(500, "Could not check donation status", selectErr);
                }

                if (rows.length === 0) {
                    return fail(404, "Donation not found");
                }

                const status = rows[0].status;
                if (status !== "Available") {
                    return fail(400, "Donation is already " + status);
                }

                connection.query(
                    "UPDATE food_donations SET status = 'Claimed' WHERE id = ?",
                    [donationId],
                    (updateErr) => {
                        if (updateErr) {
                            return fail(500, "Could not update donation status", updateErr);
                        }

                        connection.query(
                            "INSERT INTO donation_claims (donation_id, ngo_user_id) VALUES (?, ?)",
                            [donationId, ngoUserId],
                            (claimErr) => {
                                if (claimErr) {
                                    return fail(500, "Could not save donation claim", claimErr);
                                }

                                const auditSql = `
                                    INSERT INTO audit_log
                                    (action, table_name, record_id, old_value, new_value, performed_by)
                                    VALUES ('CLAIM', 'food_donations', ?, 'Available', 'Claimed', ?)
                                `;

                                connection.query(auditSql, [donationId, ngoUserId], (auditErr) => {
                                    if (auditErr) console.error(auditErr);
                                    connection.commit((commitErr) => {
                                        if (commitErr) {
                                            return fail(500, "Could not complete donation claim", commitErr);
                                        }

                                        connection.release();
                                        res.json({ message: "Donation claimed successfully" });
                                    });
                                });
                            }
                        );
                    }
                );
            });
        });
    });
});

module.exports = router;
