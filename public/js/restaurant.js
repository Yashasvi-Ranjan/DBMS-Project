const token = localStorage.getItem("token");
const role = localStorage.getItem("role");
const username = localStorage.getItem("username");

if (!token || role !== "restaurant") {
    window.location.href = "/login.html";
}

document.getElementById("welcomeMsg").textContent = "Welcome, " + username;

const donationForm = document.getElementById("donationForm");
const donationList = document.getElementById("donationList");

async function fetchDonations() {
    const res = await fetch("/api/donations", {
        headers: { "Authorization": "Bearer " + token }
    });

    if (res.status === 401 || res.status === 403) {
        logout();
        return;
    }

    const donations = await res.json();
    donationList.innerHTML = "";

    donations.forEach(function (donation) {
        const div = document.createElement("div");
        div.classList.add("donation-item");

        div.innerHTML =
            "<p><strong>Restaurant:</strong> " + donation.restaurant_name + "</p>" +
            "<p><strong>Food:</strong> " + donation.food_type + "</p>" +
            "<p><strong>Quantity:</strong> " + donation.quantity + "</p>" +
            "<p><strong>Expiry:</strong> " + new Date(donation.expiry_time).toLocaleString() + "</p>" +
            '<p class="status ' + donation.status.toLowerCase() + '">Status: ' + donation.status + "</p>";

        donationList.appendChild(div);
    });
}

donationForm.addEventListener("submit", async function (e) {
    e.preventDefault();

    const restaurantName = document.getElementById("restaurantName").value;
    const foodType = document.getElementById("foodType").value;
    const quantity = document.getElementById("quantity").value;
    const expiryTime = document.getElementById("expiryTime").value;

    const res = await fetch("/api/donations", {
        method: "POST",
        headers: {
            "Content-Type": "application/json",
            "Authorization": "Bearer " + token
        },
        body: JSON.stringify({ restaurantName, foodType, quantity, expiryTime })
    });

    if (res.ok) {
        donationForm.reset();
        fetchDonations();
    }
});

function logout() {
    localStorage.clear();
    window.location.href = "/login.html";
}

fetchDonations();
setInterval(fetchDonations, 10000);
