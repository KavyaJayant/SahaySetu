const API_URL = "http://127.0.0.1:8000";

async function loadUsersFromBackend() {
    const token = localStorage.getItem("access_token");

    const response = await fetch(
        API_URL + "/admin/users",
        {
            headers: {
                "Authorization": "Bearer " + token
            }
        }
    );

    if (!response.ok) {
        throw new Error("Failed to load users");
    }

    const data = await response.json();

    users.length = 0;

    data.forEach(function (user) {
        users.push({
            id: user.user_id,
            name: user.name,
            email: user.email,
            role: user.role,
            status: user.is_active === 1
                ? "Active"
                : "Inactive"
        });
    });

    displayUsers(users);
}
// ==========================================
// SAHAYSETU ADMINISTRATION DASHBOARD
// FRONTEND DEMO VERSION
// ==========================================


// ==========================================
// SAMPLE USERS
// ==========================================

const users = [

    {
        id: "U001",
        name: "Rahul Sharma",
        email: "rahul@gmail.com",
        role: "Citizen",
        status: "Active"
    },

    {
        id: "U002",
        name: "Priya Singh",
        email: "priya@gmail.com",
        role: "Citizen",
        status: "Active"
    },

    {
        id: "U003",
        name: "Amit Kumar",
        email: "amit@sahaysetu.in",
        role: "Worker",
        status: "Active"
    },

    {
        id: "U004",
        name: "Neha Verma",
        email: "neha@sahaysetu.in",
        role: "Authority",
        status: "Active"
    },

    {
        id: "U005",
        name: "Admin",
        email: "admin@sahaysetu.in",
        role: "Administration",
        status: "Active"
    },

    {
        id: "U006",
        name: "Rohit Gupta",
        email: "rohit@gmail.com",
        role: "Citizen",
        status: "Inactive"
    }

];


// ==========================================
// SAMPLE COMPLAINTS
// ==========================================

const complaints = [

    {
        id: "C001",
        title: "Large pothole on main road",
        location: "Raj Nagar, Ghaziabad",
        priority: "High",
        status: "Pending"
    },

    {
        id: "C002",
        title: "Streetlight not working",
        location: "Indirapuram, Ghaziabad",
        priority: "Medium",
        status: "In Progress"
    },

    {
        id: "C003",
        title: "Open drain near residential area",
        location: "Vaishali, Ghaziabad",
        priority: "High",
        status: "Resolved"
    },

    {
        id: "C004",
        title: "Garbage collection issue",
        location: "Vasundhara, Ghaziabad",
        priority: "Medium",
        status: "Pending"
    },

    {
        id: "C005",
        title: "Broken footpath",
        location: "Crossings Republik",
        priority: "Low",
        status: "Resolved"
    },

    {
        id: "C006",
        title: "Water leakage on road",
        location: "Kavi Nagar, Ghaziabad",
        priority: "High",
        status: "In Progress"
    }

];


// ==========================================
// PAGE LOAD
// ==========================================

document.addEventListener(
    "DOMContentLoaded",
    async function () {

        displayRecentComplaints();

        displayComplaints(complaints);

        try {
            await loadUsersFromBackend();
        } catch (error) {
            console.error("Error loading users:", error);
            alert(
                "Could not load users. Please log in again or check the backend."
            );
        }

    }
);


// ==========================================
// NAVIGATION
// ==========================================

function showSection(sectionId, button) {

    const sections =
        document.querySelectorAll(".section");


    sections.forEach(
        function (section) {

            section.classList.remove("active");

        }
    );


    const buttons =
        document.querySelectorAll(".nav-btn");


    buttons.forEach(
        function (btn) {

            btn.classList.remove("active");

        }
    );


    const selectedSection =
        document.getElementById(sectionId);


    if (selectedSection) {

        selectedSection.classList.add("active");

    }


    if (button) {

        button.classList.add("active");

    }


    updatePageTitle(sectionId);

}


// ==========================================
// SHOW SECTION WITHOUT BUTTON
// ==========================================

function showSectionByName(sectionId) {

    const buttons =
        document.querySelectorAll(".nav-btn");


    let button = null;


    if (sectionId === "dashboard") {
        button = buttons[0];
    }

    if (sectionId === "users") {
        button = buttons[1];
    }

    if (sectionId === "complaints") {
        button = buttons[2];
    }

    if (sectionId === "system") {
        button = buttons[3];
    }


    showSection(sectionId, button);

}


// ==========================================
// PAGE TITLES
// ==========================================

function updatePageTitle(sectionId) {

    const title =
        document.getElementById("pageTitle");

    const subtitle =
        document.getElementById("pageSubtitle");


    if (sectionId === "dashboard") {

        title.textContent =
            "Administration Dashboard";

        subtitle.textContent =
            "Overview of the SahaySetu civic management system";

    }


    else if (sectionId === "users") {

        title.textContent =
            "User Management";

        subtitle.textContent =
            "View and manage SahaySetu users";

    }


    else if (sectionId === "complaints") {

        title.textContent =
            "Complaint Management";

        subtitle.textContent =
            "Monitor complaints received from citizens";

    }


    else if (sectionId === "system") {

        title.textContent =
            "System Information";

        subtitle.textContent =
            "SahaySetu platform information";

    }

}


// ==========================================
// RECENT COMPLAINTS
// ==========================================

function displayRecentComplaints() {

    const table =
        document.getElementById(
            "recentComplaints"
        );


    table.innerHTML = "";


    const recent =
        complaints.slice(0, 5);


    recent.forEach(
        function (complaint) {

            const row =
                document.createElement("tr");


            row.innerHTML = `

                <td>${complaint.id}</td>

                <td>${complaint.title}</td>

                <td>${complaint.location}</td>

                <td>
                    ${getStatusHTML(complaint.status)}
                </td>

            `;


            table.appendChild(row);

        }
    );

}


// ==========================================
// DISPLAY USERS
// ==========================================

function displayUsers(list) {

    const table =
        document.getElementById(
            "usersTable"
        );


    table.innerHTML = "";


    if (list.length === 0) {

        table.innerHTML = `

            <tr>

                <td colspan="5">
                    No users found.
                </td>

            </tr>

        `;

        return;

    }


    list.forEach(
        function (user) {

            const row =
                document.createElement("tr");


            row.innerHTML = `

                <td>${user.id}</td>

                <td>${user.name}</td>

                <td>${user.email}</td>

                <td>${user.role}</td>

                <td>
                    ${getUserStatusHTML(user.status)}
                </td>

            `;


            table.appendChild(row);

        }
    );

}


// ==========================================
// USER SEARCH
// ==========================================

function searchUsers() {

    const search =
        document
            .getElementById("userSearch")
            .value
            .toLowerCase();


    const role =
        document
            .getElementById("roleFilter")
            .value
            .toLowerCase();


    const filtered =
        users.filter(
            function (user) {

                const text =
                    (
                        user.name +
                        " " +
                        user.email +
                        " " +
                        user.id
                    ).toLowerCase();


                const searchMatch =
                    text.includes(search);


                const roleMatch =
                    role === "all" ||
                    user.role.toLowerCase() === role;


                return searchMatch && roleMatch;

            }
        );


    displayUsers(filtered);

}


// ==========================================
// REFRESH USERS
// ==========================================

function refreshUsers() {

    displayUsers(users);

}


// ==========================================
// DISPLAY COMPLAINTS
// ==========================================

function displayComplaints(list) {

    const table =
        document.getElementById(
            "complaintsTable"
        );


    table.innerHTML = "";


    if (list.length === 0) {

        table.innerHTML = `

            <tr>

                <td colspan="5">
                    No complaints found.
                </td>

            </tr>

        `;

        return;

    }


    list.forEach(
        function (complaint) {

            const row =
                document.createElement("tr");


            row.innerHTML = `

                <td>${complaint.id}</td>

                <td>${complaint.title}</td>

                <td>${complaint.location}</td>

                <td>${complaint.priority}</td>

                <td>
                    ${getStatusHTML(complaint.status)}
                </td>

            `;


            table.appendChild(row);

        }
    );

}


// ==========================================
// COMPLAINT SEARCH
// ==========================================

function searchComplaints() {

    const search =
        document
            .getElementById("complaintSearch")
            .value
            .toLowerCase();


    const status =
        document
            .getElementById(
                "complaintStatusFilter"
            )
            .value;


    const filtered =
        complaints.filter(
            function (complaint) {

                const text =
                    (
                        complaint.id +
                        " " +
                        complaint.title +
                        " " +
                        complaint.location +
                        " " +
                        complaint.priority
                    ).toLowerCase();


                const searchMatch =
                    text.includes(search);


                let statusMatch = true;


                if (status === "pending") {

                    statusMatch =
                        complaint.status === "Pending";

                }


                if (status === "progress") {

                    statusMatch =
                        complaint.status === "In Progress";

                }


                if (status === "resolved") {

                    statusMatch =
                        complaint.status === "Resolved";

                }


                return searchMatch && statusMatch;

            }
        );


    displayComplaints(filtered);

}


// ==========================================
// REFRESH COMPLAINTS
// ==========================================

function refreshComplaints() {

    displayComplaints(complaints);

}


// ==========================================
// STATUS HTML
// ==========================================

function getStatusHTML(status) {

    let className = "pending";


    if (status === "Resolved") {

        className = "resolved";

    }


    else if (status === "In Progress") {

        className = "progress";

    }


    return `
        <span class="status ${className}">
            ${status}
        </span>
    `;

}


// ==========================================
// USER STATUS HTML
// ==========================================

function getUserStatusHTML(status) {

    if (status === "Active") {

        return `
            <span class="status resolved">
                Active
            </span>
        `;

    }


    return `
        <span class="status pending">
            Inactive
        </span>
    `;

}
