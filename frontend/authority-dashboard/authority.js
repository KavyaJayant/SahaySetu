// ==========================================
// SAHAYSETU AUTHORITY DASHBOARD
// ==========================================


// ==========================================
// BACKEND
// ==========================================

const API_URL = "http://127.0.0.1:8001";


// ==========================================
// GLOBAL DATA
// ==========================================

let allComplaints = [];
let allWorkers = [];
let allIncidents = [];
let currentComplaintWorkerId = null;

const LOGIN_PATH = "../authority-login/authority-login.html";

// ==========================================
// AUTH HELPERS
// ==========================================

function redirectToLogin(message = "Please login first.") {

    if (message) {
        alert(message);
    }

    window.location.href = LOGIN_PATH;
}

async function authFetch(url, options = {}) {
    const token = localStorage.getItem("access_token");

    if (!token) {
        redirectToLogin();
        throw new Error("Missing token");
    }

    const response = await fetch(url, {
        ...options,
        headers: {
            "Content-Type": "application/json",
            ...(options.headers || {}),
            Authorization: `Bearer ${token}`
        }
    });

    if (response.status === 401 || response.status === 403) {
        localStorage.removeItem("access_token");
        localStorage.removeItem("authority_login");
        redirectToLogin(
            response.status === 401
                ? "Your session has expired. Please login again."
                : "You do not have permission to access this portal."
        );
        throw new Error("Unauthorized");
    }

    return response;
}

async function validateAuthoritySession() {
    const token = localStorage.getItem("access_token");

    if (!token) {
        redirectToLogin();
        return false;
    }

    try {
        const response = await fetch(API_URL + "/auth/me", {
            headers: {
                Authorization: `Bearer ${token}`
            }
        });

        if (!response.ok) {
            redirectToLogin("Your authority session is invalid or expired.");
            return false;
        }

        const user = await response.json();

        if (user.role !== "AUTHORITY") {
            redirectToLogin("This account is not configured as an authority.");
            return false;
        }

        return true;
    }
    catch (error) {
        console.error("Authority validation failed:", error);
        redirectToLogin("Unable to validate your authority session.");
        return false;
    }
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

        const response = await authFetch(
            API_URL + "/authority/complaints",
            {
                method: "GET"
            }
        );


        const data =
            await response.json();


        console.log(
            "Authority API response:",
            data
        );


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

        updateFusionComplaintOptions();

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

        const complaintSelect = document.getElementById("complaintSelect");

        if (complaintSelect) {
            const previousComplaintId = complaintSelect.value;
            complaintSelect.innerHTML = '<option value="">Select a complaint</option>' +
                allComplaints.map(function(complaint) {
                    const complaintId = complaint.complaint_id || getComplaintId(complaint);
                    const workerText = complaint.assigned_worker_name
                        ? ` — assigned to ${complaint.assigned_worker_name}`
                        : " — unassigned";
                    return `<option value="${escapeHTML(complaintId)}">${escapeHTML(String(complaintId))} · ${escapeHTML(complaint.category || "Category not recorded")}${escapeHTML(workerText)}</option>`;
                }).join("");
            if (allComplaints.some(function(complaint) {
                return complaint.complaint_id === previousComplaintId;
            })) {
                complaintSelect.value = previousComplaintId;
            }
        }

        updateWorkerStatistics();

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
        complaint.complaint_id ||
        complaint.id ||
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

    if (complaint.status) {
        return complaint.status;
    }

    if (complaint.complaint_status) {
        return complaint.complaint_status;
    }

    return "SUBMITTED";

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
        value.includes("submitted") ||
        value.includes("pending") ||
        value.includes("disputed")
    ) {

        return "pending";

    }

    if (
        value.includes("assigned") ||
        value.includes("progress") ||
        value.includes("in_progress")
    ) {

        return "progress";

    }

    if (
        value.includes("resolved") ||
        value.includes("verified") ||
        value.includes("complete") ||
        value.includes("closed") ||
        value.includes("completed")
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
                status.includes("submitted") ||
                status.includes("pending") ||
                status.includes("disputed")
            ) {

                pending++;

            }

            else if (
                status.includes("assigned") ||
                status.includes("progress") ||
                status.includes("in_progress")
            ) {

                progress++;

            }

            else if (
                status.includes("resolved") ||
                status.includes("verified") ||
                status.includes("complete") ||
                status.includes("closed") ||
                status.includes("completed")
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

                    <th>Assigned Worker</th>

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
                        ${escapeHTML(complaint.assigned_worker_name || "Unassigned")}
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

                    <th>Category</th>

                    <th>Priority</th>

                    <th>Status</th>

                    <th>Assigned Worker</th>

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
                ${escapeHTML(String(complaint.category || "Not recorded"))}
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

            <td>
                ${escapeHTML(complaint.assigned_worker_name || "Unassigned")}
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
                    statusFilter === "pending"
                ) {

                    statusMatch =
                        status.includes("pending") ||
                        status.includes("submitted") ||
                        status.includes("disputed");

                }

                else if (
                    statusFilter === "progress"
                ) {

                    statusMatch =
                        status.includes("progress") ||
                        status.includes("assigned") ||
                        status.includes("in_progress");

                }

                else if (
                    statusFilter === "resolved"
                ) {

                    statusMatch =
                        status.includes("resolved") ||
                        status.includes("verified") ||
                        status.includes("complete") ||
                        status.includes("closed") ||
                        status.includes("completed");

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
                status.includes("submitted") ||
                status.includes("pending") ||
                status.includes("disputed")
            ) {

                pending++;

            }

            if (
                status.includes("resolved") ||
                status.includes("verified") ||
                status.includes("complete") ||
                status.includes("closed") ||
                status.includes("completed")
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
        LOGIN_PATH;

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
// WORKERS
// ==========================================

async function loadWorkers(expandWorkerId = null) {
    const workerSelect = document.getElementById("workerSelect");
    const workerTable = document.getElementById("workerTable");

    if (!workerSelect || !workerTable) {
        return;
    }

    const previouslyOpen = Array.from(
        workerTable.querySelectorAll("details[data-worker-id][open]")
    ).map(function(details) {
        return details.dataset.workerId;
    });

    workerTable.innerHTML = '<div class="loading">Loading workers...</div>';

    try {
        const response = await authFetch(API_URL + "/authority/workers");
        const data = await response.json();

        if (!response.ok) {
            throw new Error(data.detail || "Unable to load workers");
        }

        allWorkers = Array.isArray(data) ? data : [];

        if (allWorkers.length === 0) {
            workerTable.innerHTML = '<div class="loading">No workers are registered.</div>';
            updateWorkerStatistics();
            return;
        }

        updateWorkerStatistics();
        renderWorkerTable(previouslyOpen, expandWorkerId);
    }
    catch (error) {
        console.error("Worker load failed:", error);
        workerTable.innerHTML = '<div class="loading">Unable to load workers. Try refreshing.</div>';
    }
}

function updateWorkerStatistics() {
    const assignedCount = allComplaints.filter(function(complaint) {
        return complaint.assigned_worker_id !== null &&
            complaint.assigned_worker_id !== undefined;
    }).length;

    const totalElement = document.getElementById("workerTotal");
    const assignedElement = document.getElementById("workerAssignedTotal");
    const unassignedElement = document.getElementById("workerUnassignedTotal");

    if (totalElement) {
        totalElement.textContent = String(allWorkers.length);
    }
    if (assignedElement) {
        assignedElement.textContent = String(assignedCount);
    }
    if (unassignedElement) {
        unassignedElement.textContent = String(
            Math.max(0, allComplaints.length - assignedCount)
        );
    }
}

function renderWorkerTable(openWorkerIds = [], expandWorkerId = null) {
    const workerTable = document.getElementById("workerTable");
    const filter = document.getElementById("workerCategoryFilter");
    const selectedCategory = filter ? filter.value : "all";
    const workers = allWorkers.filter(function(worker) {
        if (selectedCategory === "all") {
            return true;
        }
        if (selectedCategory === "unclassified") {
            return !worker.worker_category;
        }
        return worker.worker_category === selectedCategory;
    });

    if (workers.length === 0) {
        workerTable.innerHTML = '<div class="loading">No workers match this category.</div>';
        return;
    }

    workerTable.innerHTML = `
        <table class="worker-table">
            <thead>
                <tr>
                    <th>Worker</th>
                    <th>Category</th>
                    <th>Availability</th>
                    <th>Assigned complaints</th>
                    <th>Details</th>
                </tr>
            </thead>
            <tbody>
                ${workers.map(function(worker) {
                    const shouldOpen = openWorkerIds.includes(String(worker.id)) ||
                        String(worker.id) === String(expandWorkerId);
                    const statusClass = worker.is_active ? "worker-active" : "worker-inactive";
                    return `
                        <tr class="worker-row">
                            <td class="worker-name-cell">
                                <strong title="${escapeHTML(worker.name)}">${escapeHTML(worker.name)}</strong>
                                ${worker.is_demo_worker ? '<span class="demo-label">Demo worker</span>' : ""}
                            </td>
                            <td>${escapeHTML(worker.worker_category || "Not assigned")}</td>
                            <td><span class="worker-status ${statusClass}">${worker.is_active ? "Active" : "Inactive"}</span></td>
                            <td>${Number(worker.assigned_complaint_count) || 0}</td>
                            <td>
                                <details class="worker-details" data-worker-id="${worker.id}" ${shouldOpen ? "open" : ""}>
                                    <summary>View complaints</summary>
                                    <div class="worker-complaints" id="worker-complaints-${worker.id}">
                                        <div class="loading">Loading assigned complaints...</div>
                                    </div>
                                </details>
                            </td>
                        </tr>
                    `;
                }).join("")}
            </tbody>
        </table>
    `;

    workerTable.querySelectorAll("details[data-worker-id]").forEach(function(details) {
        details.addEventListener("toggle", function() {
            if (details.open && details.dataset.loaded !== "true") {
                loadWorkerComplaints(details);
            }
        });
        if (details.open) {
            loadWorkerComplaints(details);
        }
    });
}

function filterWorkers() {
    const openWorkerIds = Array.from(
        document.querySelectorAll("#workerTable details[data-worker-id][open]")
    ).map(function(details) {
        return details.dataset.workerId;
    });
    renderWorkerTable(openWorkerIds);
}

function updateAssignmentButton() {
    const workerSelect = document.getElementById("workerSelect");
    const assignButton = document.getElementById("assignButton");

    if (!workerSelect || !assignButton) {
        return;
    }

    const selectedWorkerId = workerSelect.value;
    const alreadyAssigned = selectedWorkerId &&
        String(selectedWorkerId) === String(currentComplaintWorkerId);

    assignButton.disabled = workerSelect.disabled || !selectedWorkerId || alreadyAssigned;
    assignButton.textContent = alreadyAssigned
        ? "Already Assigned"
        : currentComplaintWorkerId
            ? "Reassign Worker"
            : "Assign Worker";
}

function showSelectedWorkerAssignments() {
    const workerSelect = document.getElementById("workerSelect");
    const worker = allWorkers.find(function(item) {
        return String(item.id) === String(workerSelect.value);
    });

    if (!worker) {
        return;
    }

    const categoryFilter = document.getElementById("workerCategoryFilter");
    if (categoryFilter && categoryFilter.value !== worker.worker_category) {
        categoryFilter.value = worker.worker_category || "unclassified";
    }

    renderWorkerTable([String(worker.id)], worker.id);
    const details = document.querySelector(
        `#workerTable details[data-worker-id="${worker.id}"]`
    );
    if (details) {
        details.scrollIntoView({ block: "nearest" });
    }
}

async function loadWorkerComplaints(details) {
    const workerId = details.dataset.workerId;
    const contents = document.getElementById(`worker-complaints-${workerId}`);

    if (!contents || details.dataset.loading === "true") {
        return;
    }
    details.dataset.loading = "true";
    contents.innerHTML = '<div class="loading">Loading assigned complaints...</div>';

    try {
        const response = await authFetch(
            API_URL + `/authority/workers/${encodeURIComponent(workerId)}/complaints`
        );
        const complaints = await response.json();
        if (!response.ok) {
            throw new Error(complaints.detail || "Unable to load assigned complaints");
        }
        details.dataset.loaded = "true";

        if (!Array.isArray(complaints) || complaints.length === 0) {
            contents.innerHTML = '<p class="worker-empty">No complaints are assigned to this worker.</p>';
            return;
        }

        contents.innerHTML = `
            <div class="worker-complaint-list">
                ${complaints.map(function(complaint) {
                    const date = complaint.created_at
                        ? new Date(complaint.created_at).toLocaleDateString()
                        : "Not recorded";
                    return `
                        <div class="worker-complaint">
                            <strong>${escapeHTML(complaint.complaint_id || "ID not recorded")}</strong>
                            <span>${escapeHTML(complaint.category || "Category not recorded")}</span>
                            <span>Ward: Not recorded</span>
                            <span>${escapeHTML(date)}</span>
                            <span class="status ${getStatusClass(complaint.status)}">${escapeHTML(complaint.status || "Status not recorded")}</span>
                        </div>
                    `;
                }).join("")}
            </div>
        `;
    }
    catch (error) {
        console.error("Worker complaint load failed:", error);
        contents.innerHTML = '<p class="worker-empty">Unable to load complaints. Close and reopen this row to retry.</p>';
    }
    finally {
        delete details.dataset.loading;
    }
}

async function loadEligibleWorkers() {
    const complaintSelect = document.getElementById("complaintSelect");
    const workerSelect = document.getElementById("workerSelect");
    const assignmentInfo = document.getElementById("selectedComplaintInfo");
    const assignButton = document.getElementById("assignButton");
    const complaintId = complaintSelect.value;

    workerSelect.disabled = true;
    assignButton.disabled = true;
    currentComplaintWorkerId = null;
    workerSelect.innerHTML = '<option value="">Loading eligible workers...</option>';

    if (!complaintId) {
        workerSelect.innerHTML = '<option value="">Select a complaint first</option>';
        assignmentInfo.textContent = "Select a complaint to view its current assignment and eligible workers.";
        updateAssignmentButton();
        return;
    }

    assignmentInfo.textContent = "Checking complaint category and current assignment...";

    try {
        const response = await authFetch(
            API_URL + `/authority/complaints/${encodeURIComponent(complaintId)}/eligible-workers`
        );
        const result = await response.json();

        if (!response.ok) {
            throw new Error(result.detail || "Unable to find eligible workers");
        }

        if (!result.category) {
            workerSelect.innerHTML = '<option value="">No safe category match</option>';
            assignmentInfo.textContent =
                `Category "${result.complaint_category || "not recorded"}" cannot be safely matched. No worker can be selected for this complaint.`;
            return;
        }

        const currentAssignment = result.assigned_worker_name
            ? `Currently assigned to ${result.assigned_worker_name}.`
            : "Currently unassigned.";
        currentComplaintWorkerId = result.assigned_worker_id;
        assignmentInfo.textContent = `${result.category} · ${currentAssignment}`;

        if (!Array.isArray(result.workers) || result.workers.length === 0) {
            workerSelect.innerHTML = '<option value="">No active workers in this category</option>';
            assignmentInfo.textContent += " No active category-compatible workers are available.";
            return;
        }

        workerSelect.innerHTML = '<option value="">Select a worker</option>' +
            result.workers.map(function(worker) {
                const demoLabel = worker.is_demo_worker ? " · Demo worker" : "";
                return `<option value="${worker.id}">${escapeHTML(worker.name)}${demoLabel}</option>`;
            }).join("");

        if (result.assigned_worker_id !== null && result.assigned_worker_id !== undefined &&
            result.workers.some(function(worker) {
                return worker.id === result.assigned_worker_id;
            })) {
            workerSelect.value = String(result.assigned_worker_id);
        }
        workerSelect.disabled = false;
        updateAssignmentButton();
    }
    catch (error) {
        console.error("Eligible worker lookup failed:", error);
        workerSelect.innerHTML = '<option value="">Unable to load workers</option>';
        assignmentInfo.textContent = error.message || "Unable to check category-compatible workers.";
        updateAssignmentButton();
    }
}

async function assignWorkerToComplaint() {
    const complaintSelect = document.getElementById("complaintSelect");
    const workerSelect = document.getElementById("workerSelect");
    const assignmentStatus = document.getElementById("assignmentStatus");
    const submitButton = document.getElementById("assignButton");

    if (!complaintSelect || !workerSelect) {
        return;
    }

    const complaintId = complaintSelect.value;
    const workerId = Number(workerSelect.value);

    if (!complaintId || !workerId || workerSelect.disabled) {
        assignmentStatus.textContent = "Choose a complaint and eligible worker first.";
        return;
    }

    submitButton.disabled = true;
    assignmentStatus.textContent = "Assigning worker...";

    try {
        const response = await authFetch(
            API_URL + `/authority/complaints/${encodeURIComponent(complaintId)}/assign`,
            {
                method: "PUT",
                body: JSON.stringify({ worker_id: workerId })
            }
        );

        const data = await response.json();

        if (!response.ok) {
            throw new Error(data.detail || "Assignment failed");
        }

        assignmentStatus.textContent =
            `${data.complaint_id} assigned to ${data.assigned_worker_name || "worker"} successfully.`;
        await loadComplaints();
        await loadWorkers(workerId);
        await loadEligibleWorkers();
    }
    catch (error) {
        console.error("Assignment failed:", error);
        assignmentStatus.textContent = error.message || "Unable to assign worker.";
    }
    finally {
        updateAssignmentButton();
    }
}

// ==========================================
// INCIDENTS
// ==========================================

async function loadIncidents() {
    const incidentList = document.getElementById("incidentList");

    if (!incidentList) {
        return;
    }

    incidentList.innerHTML = '<div class="loading">Loading incidents...</div>';

    try {
        const response = await authFetch(API_URL + "/authority/incidents");
        const data = await response.json();

        if (!response.ok) {
            throw new Error(data.detail || "Unable to load incidents");
        }

        allIncidents = Array.isArray(data) ? data : [];

        if (allIncidents.length === 0) {
            incidentList.innerHTML = '<div class="loading">No incidents available.</div>';
            return;
        }

        incidentList.innerHTML = allIncidents.map(function(incident) {
            return `
                <div class="list-row">
                    <div>
                        <strong>${escapeHTML(incident.incident_id || "Unknown incident")}</strong>
                        <small>${escapeHTML(incident.title || incident.incident_type || "Civic incident")}</small>
                    </div>
                    <div class="status-group">
                        <span class="status progress">${escapeHTML(incident.status || "DETECTED")}</span>
                        <small>${incident.complaint_count || 0} complaints</small>
                    </div>
                    <button type="button" class="incident-analysis-button"
                        data-incident-id="${escapeHTML(String(incident.incident_id || ""))}">
                        Review analysis
                    </button>
                </div>
            `;
        }).join("");

        incidentList.querySelectorAll(".incident-analysis-button").forEach(function(button) {
            button.addEventListener("click", function() {
                loadIncidentAnalysis(button.dataset.incidentId);
            });
        });
    }
    catch (error) {
        console.error("Incident load failed:", error);
        incidentList.innerHTML = `
            <div class="loading">
                <p>Unable to load incidents: ${escapeHTML(error.message || "Unknown error")}</p>
                <button type="button" id="retryIncidentsButton">Try again</button>
            </div>`;
        document.getElementById("retryIncidentsButton")?.addEventListener(
            "click",
            loadIncidents
        );
    }
}

function updateFusionComplaintOptions() {
    const select = document.getElementById("fusionComplaintSelect");
    if (!select) {
        return;
    }

    const unlinked = allComplaints.filter(function(complaint) {
        return !complaint.incident_id;
    });
    if (unlinked.length === 0) {
        select.innerHTML = '<option value="">No unlinked complaints available</option>';
        return;
    }

    select.innerHTML = '<option value="">Select a complaint</option>' +
        unlinked.map(function(complaint) {
            const id = getComplaintId(complaint);
            return `<option value="${escapeHTML(String(id))}">${escapeHTML(String(id))} · ${escapeHTML(complaint.category || "Category not recorded")}</option>`;
        }).join("");
}

async function fuseSelectedComplaint() {
    const select = document.getElementById("fusionComplaintSelect");
    const button = document.getElementById("fuseComplaintButton");
    const status = document.getElementById("fusionStatus");
    const complaintId = select?.value;
    if (!complaintId || !button || !status) {
        status.textContent = "Select an unlinked complaint first.";
        status.className = "form-status error";
        return;
    }

    button.disabled = true;
    status.textContent = "Checking existing reports...";
    status.className = "form-status";
    try {
        const result = await requestAuthorityJson(
            `/authority/incidents/fuse/${encodeURIComponent(complaintId)}`,
            { method: "POST" }
        );
        if (result.incident_id) {
            status.textContent =
                `Probable incident ${result.incident_id} was saved with ${result.complaint_count} linked complaints.`;
            status.className = "form-status success";
        } else {
            status.textContent =
                result.message || "No related complaints were found; no incident was created.";
            status.className = "form-status";
        }
        await Promise.all([loadComplaints(), loadIncidents()]);
    }
    catch (error) {
        status.textContent = error.message || "Unable to analyze this complaint.";
        status.className = "form-status error";
    }
    finally {
        button.disabled = false;
    }
}

async function requestAuthorityJson(path, options = {}) {
    const response = await authFetch(API_URL + path, options);
    const data = await response.json();
    if (!response.ok) {
        throw new Error(data.detail || "The server request failed.");
    }
    return data;
}

async function loadIncidentAnalysis(incidentId, notice = "") {
    const panel = document.getElementById("incidentAnalysisPanel");
    if (!panel || !incidentId) {
        return;
    }
    panel.hidden = false;
    panel.innerHTML = '<div class="loading">Loading incident analysis and records...</div>';
    const path = `/authority/incidents/${encodeURIComponent(incidentId)}`;

    try {
        const [
            relationships,
            assessment,
            recurrence,
            prevention,
            workRecords,
            recoveryRecords
        ] = await Promise.all([
            requestAuthorityJson(`${path}/relationships`),
            requestAuthorityJson(`${path}/interventions`),
            requestAuthorityJson(`${path}/recurrence`),
            requestAuthorityJson(`${path}/prevention`),
            requestAuthorityJson(`${path}/interventions/records`),
            requestAuthorityJson(`${path}/recovery`)
        ]);

        const relationshipItems = relationships.relationships || [];
        const recommendationItems = assessment.interventions || [];
        const recurrenceItems = recurrence.recurrence_candidates || [];
        const preventionItems = prevention.recommendations || [];

        panel.innerHTML = `
            <div class="panel-header">
                <div>
                    <h2>Incident ${escapeHTML(incidentId)}</h2>
                    <p>Review hypotheses separately from saved work and observations.</p>
                </div>
                <button type="button" id="closeIncidentAnalysis">Close</button>
            </div>
            <p class="form-status success analysis-feedback" role="status">${escapeHTML(notice)}</p>
            <p class="analysis-disclaimer">
                Relationship, recurrence and prevention results are rule-based screening aids, not proof of causation, physical identity or measured intervention impact.
            </p>
            <section class="analysis-card">
                <h3>Civic relationship analysis</h3>
                ${relationshipItems.length
                    ? `<ul>${relationshipItems.map(item => `
                        <li><strong>${escapeHTML(item.relationship || "Relationship")}</strong>:
                        ${escapeHTML(item.complaint_1 || "")} (${escapeHTML(item.category_1 || "")}) and
                        ${escapeHTML(item.complaint_2 || "")} (${escapeHTML(item.category_2 || "")}) —
                        ${escapeHTML(item.explanation || "")}</li>`).join("")}</ul>`
                    : '<p>No defined relationship was returned for the complaints in this incident.</p>'}
            </section>
            <section class="analysis-card">
                <h3>Candidate interventions — rule-based, not measured outcomes</h3>
                ${recommendationItems.length
                    ? `<ul>${recommendationItems.map(item => `
                        <li><strong>#${escapeHTML(String(item.rank ?? ""))} ${escapeHTML(item.intervention || "")}</strong>
                        — expected impact estimate ${escapeHTML(String(item.expected_impact_score ?? "not scored"))}/100 (${escapeHTML(item.impact || "unrated")})
                        ${escapeHTML((item.reasons || []).join(" "))}</li>`).join("")}</ul>`
                    : '<p>No rule-based intervention candidates are available.</p>'}
                ${recommendationItems.length ? `
                    <form id="createInterventionForm" class="analysis-form-row">
                        <label class="analysis-field">Create a work record
                            <select name="intervention_type" required>
                                ${recommendationItems.map(item => `
                                    <option value="${escapeHTML(item.intervention || "")}"
                                        data-score="${escapeHTML(String(item.expected_impact_score ?? ""))}">
                                        ${escapeHTML(item.intervention || "")}
                                    </option>`).join("")}
                            </select>
                        </label>
                        <label class="analysis-field">Work note (optional)
                            <input name="notes" maxlength="2000">
                        </label>
                        <button type="submit" class="btn-primary">Save work record</button>
                    </form>` : ""}
            </section>
            <section class="analysis-card">
                <h3>Saved intervention/work records</h3>
                ${workRecords.length
                    ? workRecords.map(record => `
                        <div class="analysis-card">
                            <strong>${escapeHTML(record.intervention_type || "Work record")}</strong>
                            <span> · ${escapeHTML(record.intervention_id || "")} · ${escapeHTML(record.status || "Status not recorded")}</span>
                            ${record.notes ? `<p>${escapeHTML(record.notes)}</p>` : ""}
                            ${record.status === "PLANNED"
                                ? `<button type="button" data-work-id="${escapeHTML(record.intervention_id)}" data-work-status="IN_PROGRESS">Start work</button>`
                                : record.status === "IN_PROGRESS"
                                    ? `<button type="button" data-work-id="${escapeHTML(record.intervention_id)}" data-work-status="COMPLETED">Mark completed</button>`
                                    : ""}
                        </div>`).join("")
                    : "<p>No work records have been created for this incident.</p>"}
            </section>
            <section class="analysis-card">
                <h3>Recovery observations</h3>
                ${recoveryRecords.length
                    ? `<ul>${recoveryRecords.map(record => `
                        <li><strong>${escapeHTML(record.observation_status || "Status not recorded")}</strong>
                        — score ${escapeHTML(String(record.recovery_score ?? "not recorded"))}/100
                        ${record.notes ? ` · ${escapeHTML(record.notes)}` : ""}
                        ${record.evidence ? ` · ${escapeHTML(record.evidence)}` : ""}</li>`).join("")}</ul>`
                    : "<p>No recovery observations have been saved.</p>"}
                ${workRecords.length ? `
                    <form id="recoveryObservationForm" class="analysis-form-row">
                        <label class="analysis-field">Work record
                            <select name="intervention_id" required>
                                ${workRecords.map(record => `
                                    <option value="${escapeHTML(record.intervention_id)}">
                                        ${escapeHTML(record.intervention_type)} · ${escapeHTML(record.status)}
                                    </option>`).join("")}
                            </select>
                        </label>
                        <label class="analysis-field">Recovery score (0–100)
                            <input name="recovery_score" type="number" min="0" max="100" step="0.1" required>
                        </label>
                        <label class="analysis-field">Observation notes
                            <input name="notes" maxlength="2000">
                        </label>
                        <label class="analysis-field">Evidence description
                            <input name="evidence" maxlength="2000">
                        </label>
                        <button type="submit" class="btn-primary">Save observation</button>
                    </form>` : "<p>Create a saved work record before recording recovery for it.</p>"}
            </section>
            <section class="analysis-card">
                <h3>Recurrence screening</h3>
                <p>${recurrence.recurrence_detected
                    ? `Potential recurrence candidates: ${escapeHTML(String(recurrence.recurrence_count ?? recurrenceItems.length))}.`
                    : "No recurrence candidates were returned using the current rules and available recovery data."}</p>
                ${recurrenceItems.length
                    ? `<ul>${recurrenceItems.map(item => `<li>${escapeHTML(item.complaint_id || "")} · ${escapeHTML(item.category || "")} · ${escapeHTML(String(item.distance_meters ?? "distance unavailable"))} m</li>`).join("")}</ul>`
                    : ""}
            </section>
            <section class="analysis-card">
                <h3>Preventive recommendations — separate from confirmed work</h3>
                ${preventionItems.length
                    ? `<ul>${preventionItems.map(item => `<li><strong>${escapeHTML(item.recommendation || "")}</strong> (${escapeHTML(item.priority || "unrated")}) — ${escapeHTML(item.reason || "")}</li>`).join("")}</ul>`
                    : "<p>No preventive recommendations are currently supported by the available recurrence result.</p>"}
            </section>`;

        panel.querySelector("#closeIncidentAnalysis")?.addEventListener("click", function() {
            panel.hidden = true;
        });
        panel.querySelector("#createInterventionForm")?.addEventListener("submit", async function(event) {
            event.preventDefault();
            const form = event.currentTarget;
            const selected = form.elements.intervention_type.selectedOptions[0];
            const scoreText = selected.dataset.score;
            const feedback = panel.querySelector(".analysis-feedback");
            try {
                await requestAuthorityJson(`${path}/interventions`, {
                    method: "POST",
                    body: JSON.stringify({
                        intervention_type: selected.value,
                        expected_impact_score: scoreText ? Number(scoreText) : null,
                        notes: form.elements.notes.value.trim() || null
                    })
                });
                await loadIncidentAnalysis(incidentId, "Work record saved by the server.");
            } catch (error) {
                feedback.textContent = error.message || "Unable to save work record.";
                feedback.className = "form-status error analysis-feedback";
            }
        });
        panel.querySelectorAll("[data-work-id][data-work-status]").forEach(function(button) {
            button.addEventListener("click", async function() {
                const feedback = panel.querySelector(".analysis-feedback");
                button.disabled = true;
                try {
                    await requestAuthorityJson(
                        `/authority/interventions/${encodeURIComponent(button.dataset.workId)}/status`,
                        {
                            method: "PUT",
                            body: JSON.stringify({ status: button.dataset.workStatus })
                        }
                    );
                    await loadIncidentAnalysis(incidentId, "Work status saved by the server.");
                } catch (error) {
                    feedback.textContent = error.message || "Unable to update work status.";
                    feedback.className = "form-status error analysis-feedback";
                    button.disabled = false;
                }
            });
        });
        panel.querySelector("#recoveryObservationForm")?.addEventListener("submit", async function(event) {
            event.preventDefault();
            const form = event.currentTarget;
            const feedback = panel.querySelector(".analysis-feedback");
            try {
                await requestAuthorityJson(`${path}/recovery`, {
                    method: "POST",
                    body: JSON.stringify({
                        incident_id: incidentId,
                        intervention_id: form.elements.intervention_id.value,
                        recovery_score: Number(form.elements.recovery_score.value),
                        evidence: form.elements.evidence.value.trim() || null,
                        notes: form.elements.notes.value.trim() || null
                    })
                });
                await loadIncidentAnalysis(incidentId, "Recovery observation saved by the server.");
            } catch (error) {
                feedback.textContent = error.message || "Unable to save recovery observation.";
                feedback.className = "form-status error analysis-feedback";
            }
        });
    }
    catch (error) {
        panel.innerHTML = `
            <p class="analysis-error">Unable to load incident analysis: ${escapeHTML(error.message || "Unknown error")}</p>
            <button type="button" id="retryIncidentAnalysis">Try again</button>`;
        panel.querySelector("#retryIncidentAnalysis")?.addEventListener("click", function() {
            loadIncidentAnalysis(incidentId);
        });
    }
}

// ==========================================
// START DASHBOARD
// ==========================================

document.getElementById("fuseComplaintButton")?.addEventListener(
    "click",
    fuseSelectedComplaint
);

showUser();

validateAuthoritySession().then(function(isValid) {
    if (isValid) {
        loadComplaints();
        loadWorkers();
        loadIncidents();
    }
});