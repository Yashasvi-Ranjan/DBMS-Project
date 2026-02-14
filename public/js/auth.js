let isLogin = true;

function showTab(tab) {
    isLogin = tab === "login";
    document.getElementById("loginTab").classList.toggle("active", isLogin);
    document.getElementById("registerTab").classList.toggle("active", !isLogin);
    document.getElementById("roleGroup").classList.toggle("show", !isLogin);
    document.getElementById("submitBtn").textContent = isLogin ? "Login" : "Register";
    document.getElementById("errorMsg").textContent = "";
}

document.getElementById("authForm").addEventListener("submit", async function (e) {
    e.preventDefault();

    const username = document.getElementById("username").value;
    const password = document.getElementById("password").value;
    const role = document.getElementById("role").value;
    const errorMsg = document.getElementById("errorMsg");

    const url = isLogin ? "/api/auth/login" : "/api/auth/register";
    const body = isLogin ? { username, password } : { username, password, role };

    try {
        const res = await fetch(url, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify(body)
        });

        const data = await res.json();

        if (!res.ok) {
            errorMsg.textContent = data.message;
            return;
        }

        localStorage.setItem("token", data.token);
        localStorage.setItem("role", data.role);
        localStorage.setItem("username", username);

        window.location.href = data.role === "restaurant"
            ? "/restaurant.html"
            : "/ngo.html";

    } catch (err) {
        errorMsg.textContent = "Server error. Please try again.";
    }
});

// If already logged in, redirect to dashboard
const token = localStorage.getItem("token");
const role = localStorage.getItem("role");
if (token && role) {
    window.location.href = role === "restaurant" ? "/restaurant.html" : "/ngo.html";
}
