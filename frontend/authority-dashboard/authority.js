// ==========================================
// SAHAYSETU AUTHORITY DASHBOARD
// ==========================================


// ==========================================
// BACKEND
// ==========================================

const API_URL = "http://127.0.0.1:8000";


// ==========================================
// GLOBAL DATA
// ==========================================

let allComplaints = [];


// ==========================================
// CHECK LOGIN
// ==========================================

const token = localStorage.getItem("access_token");


if (!token) {

    alert("Please login first.");

    window.location.href = "authority-login.html";

}


// ==========================================
// SHOW SECTION
// ==========================================

function showSection(sectionId, clickedButton) {

    const sections =
        document.querySelectorAll(".page-section");


    sections.forEach(function(section) {

        section.classList.remove(
            "active-section"
        );

    });


    const selectedSection =
        document.getElementById(sectionId);


    if (selectedSection) {

        selectedSection.classList.add(
            "active-section"
        );

    }


    const buttons =
        document.querySelectorAll(".nav-item");


    buttons.forEach(function(button) {

        button.classList.remove("active");

    });


    if (clickedButton) {

        clickedButton.classList.add("active");

    }


    // Close mobile sidebar
    document
        .getElementById("sidebar")
        .classList.remove("open");

}


// ==========================================
// SHOW SECTION BY ID
// ==========================================

function showSectionById(sectionId) {

    const buttons =
        document.querySelectorAll(".nav-item");


    let matchingButton = null;


    buttons.forEach(function(button) {

        const onclickText =
            button.getAttribute("onclick");


        if (
            onclickText &&
            onclickText.includes(
                "'" + sectionId + "'"
            )
        ) {

            matchingButton = button;

        }

    });


    showSection(
        sectionId,
        matchingButton
    );

}


// ==========================================
// MOBILE SIDEBAR
// ==========================================

function toggleSidebar() {

    document
        .getElementById("sidebar")
        .classList.toggle("open");

}


// ==========================================
// LOAD COMPLAINTS
// ==========================================

async function loadComplaints() {

    const recentContainer =
        document.getElementById(
            "recentComplaints"
        );


    const tableContainer =
        document.getElementById(
            "complaintsTable"
        );


    recentContainer.innerHTML =
        '<div class="loading">Loading complaints...</div>';


    tableContainer.innerHTML =
        '<div class="loading">Loading complaints...</div>';


    try {

        const response = await fetch(
            API_URL + "/authority/complaints",
            {
                method: "GET",

                headers: {
                    "Authorization":
                        "Bearer " + token,

                    "Content-Type":
                        "application/json"
                }
            }
        );


        const data =
            await response.json();


        console.log(
            "Authority API response:",
            data
        );


        // ======================================
        // UNAUTHORIZED
        // ======================================

        if (response.status === 401) {

            localStorage.removeItem(
                "access_token"
            );


            localStorage.removeItem(
                "authority_login"
            );


            alert(
                "Your session has expired. Please login again."
            );


            window.location.href =
                "authority-login.html";


            return;

        }


        // ======================================
        // BACKEND ERROR
        // ======================================

        if (!response.ok) {

            console.error(
                "Backend error:",
                data
            );


            recentContainer.innerHTML =
                '<div class="loading">Unable to load complaints.</div>';


            tableContainer.innerHTML =
                '<div class="loading">Unable to load complaints.</div>';


            return;

        }


        // ======================================
        // NORMALIZE DATA
        // ======================================

        allComplaints =
            normalizeComplaints(data);


        console.log(
            "Complaints:",
            allComplaints
        );


        // ======================================
        // UPDATE DASHBOARD
        // ======================================

        updateStatistics(
            allComplaints
        );


        updatePriority(
            allComplaints
        );


        displayRecentComplaints(
            allComplaints
        );


        displayComplaintsTable(
            allComplaints
        );


        updateReports(
            allComplaints
        );

    }


    catch (error) {

        console.error(
            "Connection error:",
            error
        );


        recentContainer.innerHTML =
            '<div class="loading">Cannot connect to backend.</div>';


        tableContainer.innerHTML =
            '<div class="loading">Cannot connect to backend.</div>';


        alert(
            "Cannot connect to the SahaySetu backend.\n\n" +
            "Make sure your friend's FastAPI server is running."
        );

    }

}


// ==========================================
// NORMALIZE BACKEND DATA
// ==========================================

function normalizeComplaints(data) {

    if (Array.isArray(data)) {

        return data;

    }


    if (
        data &&
        Array.isArray(data.complaints)
    ) {

        return data.complaints;

    }


    if (
        data &&
        Array.isArray(data.data)
    ) {

        return data.data;

    }


    if (
        data &&
        Array.isArray(data.results)
    ) {

        return data.results;

    }


    return [];

}


// ==========================================
// GET COMPLAINT ID
// ==========================================

function getComplaintId(complaint) {

    return (
        complaint.id ||
        complaint.complaint_id ||
        complaint.complaintId ||
        "N/A"
    );

}


// ==========================================
// GET DESCRIPTION
// ==========================================

function getDescription(complaint) {

    return (
        complaint.description ||
        complaint.title ||
        complaint.issue ||
        complaint.problem ||
        "Civic complaint"
    );

}


// ==========================================
// GET LOCATION
// ==========================================

function getLocation(complaint) {

    return (
        complaint.location ||
        complaint.address ||
        complaint.area ||
        "Not available"
    );

}


// ==========================================
// GET STATUS
// ==========================================

function getStatus(complaint) {

    return (
        complaint.status ||
        complaint.complaint_status ||
        "Unknown"
    );

}


// ==========================================
// GET PRIORITY
// ==========================================

function getPriority(complaint) {

    return (
        complaint.priority ||
        complaint.severity ||
        complaint.level ||
        "Low"
    );

}


// ==========================================
// STATUS CLASS
// ==========================================

function getStatusClass(status) {

    const value =
        String(status).toLowerCase();


    if (
        value.includes("pending")
    ) {

        return "pending";

    }


    if (
        value.includes("progress") ||
        value.includes("assigned")
    ) {

        return "progress";

    }


    if (
        value.includes("resolved") ||
        value.includes("complete") ||
        value.includes("closed")
    ) {

        return "resolved";

    }


    return "unknown";

}


// ==========================================
// UPDATE STATISTICS
// ==========================================

function updateStatistics(
    complaints
) {

    let pending = 0;

    let progress = 0;

    let resolved = 0;


    complaints.forEach(
        function(complaint) {

            const status =
                String(
                    getStatus(complaint)
                ).toLowerCase();


            if (
                status.includes("pending")
            ) {

                pending++;

            }


            else if (
                status.includes("progress") ||
                status.includes("assigned")
            ) {

                progress++;

            }


            else if (
                status.includes("resolved") ||
                status.includes("complete") ||
                status.includes("closed")
            ) {

                resolved++;

            }

        }
    );


    document.getElementById(
        "totalComplaints"
    ).textContent =
        complaints.length;


    document.getElementById(
        "pendingComplaints"
    ).textContent =
        pending;


    document.getElementById(
        "progressComplaints"
    ).textContent =
        progress;


    document.getElementById(
        "resolvedComplaints"
    ).textContent =
        resolved;

}


// ==========================================
// UPDATE PRIORITY
// ==========================================

function updatePriority(
    complaints
) {

    let high = 0;

    let medium = 0;

    let low = 0;


    complaints.forEach(
        function(complaint) {

            const priority =
                String(
                    getPriority(complaint)
                ).toLowerCase();


            if (
                priority.includes("high") ||
                priority.includes("serious") ||
                priority.includes("critical")
            ) {

                high++;

            }


            else if (
                priority.includes("medium") ||
                priority.includes("moderate")
            ) {

                medium++;

            }


            else {

                low++;

            }

        }
    );


    document.getElementById(
        "highPriority"
    ).textContent = high;


    document.getElementById(
        "mediumPriority"
    ).textContent = medium;


    document.getElementById(
        "lowPriority"
    ).textContent = low;

}


// ==========================================
// RECENT COMPLAINTS
// ==========================================

function displayRecentComplaints(
    complaints
) {

    const container =
        document.getElementById(
            "recentComplaints"
        );


    if (
        complaints.length === 0
    ) {

        container.innerHTML =
            '<div class="loading">No complaints found.</div>';

        return;

    }


    const recent =
        complaints.slice(0, 5);


    let html = `

        <table class="complaint-table">

            <thead>

                <tr>

                    <th>ID</th>

                    <th>Issue</th>

                    <th>Location</th>

                    <th>Status</th>

                </tr>

            </thead>

            <tbody>

    `;


    recent.forEach(
        function(complaint) {

            const id =
                getComplaintId(complaint);


            const description =
                getDescription(complaint);


            const location =
                getLocation(complaint);


            const status =
                getStatus(complaint);


            const statusClass =
                getStatusClass(status);


            html += `

                <tr>

                    <td>
                        <span class="complaint-id">
                            #${id}
                        </span>
                    </td>

                    <td>
                        ${escapeHTML(
                            description
                        )}
                    </td>

                    <td>
                        ${escapeHTML(
                            location
                        )}
                    </td>

                    <td>

                        <span class="status ${statusClass}">
                            ${escapeHTML(
                                status
                            )}
                        </span>

                    </td>

                </tr>

            `;

        }
    );


    html += `

            </tbody>

        </table>

    `;


    container.innerHTML = html;

}


// ==========================================
// FULL COMPLAINT TABLE
// ==========================================

function displayComplaintsTable(
    complaints
) {

    const container =
        document.getElementById(
            "complaintsTable"
        );


    if (
        complaints.length === 0
    ) {

        container.innerHTML =
            '<div class="loading">No complaints found.</div>';

        return;

    }


    let html = `

        <table class="complaint-table">

            <thead>

                <tr>

                    <th>ID</th>

                    <th>Complaint</th>

                    <th>Location</th>

                    <th>Priority</th>

                    <th>Status</th>

                </tr>

            </thead>

            <tbody id="complaintRows">

    `;


    complaints.forEach(
        function(complaint) {

            html += createComplaintRow(
                complaint
            );

        }
    );


    html += `

            </tbody>

        </table>

    `;


    container.innerHTML = html;

}


// ==========================================
// CREATE TABLE ROW
// ==========================================

function createComplaintRow(
    complaint
) {

    const id =
        getComplaintId(complaint);


    const description =
        getDescription(complaint);


    const location =
        getLocation(complaint);


    const status =
        getStatus(complaint);


    const priority =
        getPriority(complaint);


    const statusClass =
        getStatusClass(status);


    return `

        <tr
            data-status="${String(
                status
            ).toLowerCase()}"

            data-priority="${String(
                priority
            ).toLowerCase()}"
        >

            <td>

                <span class="complaint-id">
                    #${escapeHTML(
                        String(id)
                    )}
                </span>

            </td>


            <td>
                ${escapeHTML(
                    String(description)
                )}
            </td>


            <td>
                ${escapeHTML(
                    String(location)
                )}
            </td>


            <td>
                ${escapeHTML(
                    String(priority)
                )}
            </td>


            <td>

                <span class="status ${statusClass}">
                    ${escapeHTML(
                        String(status)
                    )}
                </span>

            </td>

        </tr>

    `;

}


// ==========================================
// FILTER COMPLAINTS
// ==========================================

function filterComplaints() {

    const search =
        document
            .getElementById(
                "searchInput"
            )
            .value
            .toLowerCase();


    const statusFilter =
        document
            .getElementById(
                "statusFilter"
            )
            .value
            .toLowerCase();


    const priorityFilter =
        document
            .getElementById(
                "priorityFilter"
            )
            .value
            .toLowerCase();


    const rows =
        document.querySelectorAll(
            "#complaintRows tr"
        );


    rows.forEach(
        function(row) {

            const text =
                row.textContent.toLowerCase();


            const status =
                row.dataset.status || "";


            const priority =
                row.dataset.priority || "";


            const searchMatch =
                text.includes(search);


            let statusMatch = true;

            let priorityMatch = true;


            if (
                statusFilter !== "all"
            ) {

                if (
                    statusFilter === "progress"
                ) {

                    statusMatch =
                        status.includes(
                            "progress"
                        ) ||
                        status.includes(
                            "assigned"
                        );

                }

                else {

                    statusMatch =
                        status.includes(
                            statusFilter
                        );

                }

            }


            if (
                priorityFilter !== "all"
            ) {

                priorityMatch =
                    priority.includes(
                        priorityFilter
                    );

            }


            if (
                searchMatch &&
                statusMatch &&
                priorityMatch
            ) {

                row.style.display = "";

            }

            else {

                row.style.display = "none";

            }

        }
    );

}


// ==========================================
// REPORTS
// ==========================================

function updateReports(
    complaints
) {

    let pending = 0;

    let resolved = 0;


    complaints.forEach(
        function(complaint) {

            const status =
                String(
                    getStatus(complaint)
                ).toLowerCase();


            if (
                status.includes("pending")
            ) {

                pending++;

            }


            if (
                status.includes("resolved") ||
                status.includes("complete") ||
                status.includes("closed")
            ) {

                resolved++;

            }

        }
    );


    document.getElementById(
        "reportTotal"
    ).textContent =
        complaints.length;


    document.getElementById(
        "reportPending"
    ).textContent =
        pending;


    document.getElementById(
        "reportResolved"
    ).textContent =
        resolved;

}


// ==========================================
// ESCAPE HTML
// ==========================================

function escapeHTML(value) {

    const div =
        document.createElement("div");


    div.textContent = value;


    return div.innerHTML;

}


// ==========================================
// LOGOUT
// ==========================================

function logout() {

    localStorage.removeItem(
        "access_token"
    );


    localStorage.removeItem(
        "authority_login"
    );


    window.location.href =
        "authority-login.html";

}


// ==========================================
// SHOW LOGGED-IN USER
// ==========================================

function showUser() {

    const login =
        localStorage.getItem(
            "authority_login"
        );


    const emailElement =
        document.getElementById(
            "authorityEmail"
        );


    if (
        login &&
        emailElement
    ) {

        emailElement.textContent =
            login;

    }

}


// ==========================================
// START DASHBOARD
// ==========================================

showUser();

loadComplaints();