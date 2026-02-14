const jwt = require("jsonwebtoken");

const JWT_SECRET = "food_waste_jwt_secret_key";

function verifyToken(req, res, next) {
    const header = req.headers["authorization"];
    if (!header) return res.status(401).json({ message: "No token provided" });

    const token = header.split(" ")[1];
    if (!token) return res.status(401).json({ message: "Invalid token format" });

    jwt.verify(token, JWT_SECRET, (err, decoded) => {
        if (err) return res.status(403).json({ message: "Invalid or expired token" });
        req.user = decoded;
        next();
    });
}

module.exports = { verifyToken, JWT_SECRET };
