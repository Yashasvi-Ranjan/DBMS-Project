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

const formFeedback = document.getElementById("formFeedback");

function showFeedback(message, isError) {
    formFeedback.textContent = isError ? "Oracle Trigger Error: " + message : message;
    formFeedback.className   = "form-feedback " + (isError ? "form-feedback-error" : "form-feedback-success");
    formFeedback.style.display = "block";
}

donationForm.addEventListener("submit", async function (e) {
    e.preventDefault();
    formFeedback.style.display = "none";

    const foodType    = document.getElementById("foodType").value;
    const quantity    = document.getElementById("quantity").value;
    const expiryTime  = document.getElementById("expiryTime").value;
    const pickupNotes = document.getElementById("pickupNotes").value;

    const res  = await fetch("/api/donations", {
        method: "POST",
        headers: {
            "Content-Type": "application/json",
            "Authorization": "Bearer " + token
        },
        body: JSON.stringify({ foodType, quantity, expiryTime, pickupNotes })
    });

    const data = await res.json();

    if (res.ok) {
        donationForm.reset();
        showFeedback("Donation added successfully!", false);
        fetchDonations();
    } else {
        showFeedback(data.message, true);
    }
});

function logout() {
    localStorage.clear();
    window.location.href = "/login.html";
}

fetchDonations();
setInterval(fetchDonations, 10000);
