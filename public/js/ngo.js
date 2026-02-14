const token = localStorage.getItem("token");
const role = localStorage.getItem("role");
const username = localStorage.getItem("username");

if (!token || role !== "ngo") {
    window.location.href = "/login.html";
}

document.getElementById("welcomeMsg").textContent = "Welcome, " + username;

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

        let claimBtn = "";
        if (donation.status === "Available") {
            claimBtn = '<button onclick="claimDonation(' + donation.id + ')">Claim</button>';
        }

        div.innerHTML =
            "<p><strong>Restaurant:</strong> " + donation.restaurant_name + "</p>" +
            "<p><strong>Food:</strong> " + donation.food_type + "</p>" +
            "<p><strong>Quantity:</strong> " + donation.quantity + "</p>" +
            "<p><strong>Expiry:</strong> " + new Date(donation.expiry_time).toLocaleString() + "</p>" +
            '<p class="status ' + donation.status.toLowerCase() + '">Status: ' + donation.status + "</p>" +
            claimBtn;

        donationList.appendChild(div);
    });
}

async function claimDonation(id) {
    const res = await fetch("/api/donations/" + id + "/claim", {
        method: "PUT",
        headers: { "Authorization": "Bearer " + token }
    });

    if (res.ok) {
        fetchDonations();
    }
}

function logout() {
    localStorage.clear();
    window.location.href = "/login.html";
}

fetchDonations();
setInterval(fetchDonations, 10000);
