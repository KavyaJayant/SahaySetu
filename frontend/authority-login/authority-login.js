// ==========================================
// SAHAYSETU - AUTHORITY LOGIN
// ==========================================

// FASTAPI BACKEND
const API_URL = "http://127.0.0.1:8000";


// Get login form
const loginForm = document.getElementById("loginForm");


// ==========================================
// LOGIN
// ==========================================

loginForm.addEventListener("submit", async function (event) {

    // Stop page from refreshing
    event.preventDefault();


    // Get entered values
    const login =
        document.getElementById("login").value.trim();

    const password =
        document.getElementById("password").value;


    // Check empty fields
    if (login === "" || password === "") {

        alert(
            "Please enter your Email ID/Phone Number and Password."
        );

        return;
    }


    // Login button
    const loginButton =
        document.getElementById("loginButton");


    loginButton.disabled = true;
    loginButton.textContent = "Logging in...";


    try {

        // ==========================================
        // SEND LOGIN REQUEST TO FASTAPI
        // ==========================================

        const formData = new URLSearchParams();

        formData.append("username", login);
        formData.append("password", password);


        const response = await fetch(
    API_URL + "/auth/login",
    {
        method: "POST",

        headers: {
            "Content-Type": "application/json"
        },

        body: JSON.stringify({
            email: login,
            password: password
        })
    }
);


        // ==========================================
        // READ BACKEND RESPONSE
        // ==========================================

        const data = await response.json();


        console.log("Login response:", data);


        // ==========================================
        // LOGIN FAILED
        // ==========================================

        if (!response.ok) {

            alert(
                data.detail ||
                "Login failed. Please check your login details."
            );

            loginButton.disabled = false;
            loginButton.textContent = "Login";

            return;
        }


        // ==========================================
        // LOGIN SUCCESSFUL
        // ==========================================

        if (data.access_token) {

            // Save token
            localStorage.setItem(
                "access_token",
                data.access_token
            );


            // Save login information
            localStorage.setItem(
                "authority_login",
                login
            );


            console.log("Authority login successful.");


            // Go to Authority Dashboard
            window.location.href = "../AUTHO-DASHBOARD/authority.html";

        } else {

            alert(
                "Login successful, but the backend did not send an access token."
            );

            loginButton.disabled = false;
            loginButton.textContent = "Login";
        }

    }


    // ==========================================
    // CONNECTION ERROR
    // ==========================================

    catch (error) {

        console.error("Backend connection error:", error);

        alert(
            "Cannot connect to the SahaySetu server.\n\n" +
            "Please make sure the backend is running."
        );

        loginButton.disabled = false;
        loginButton.textContent = "Login";
    }

});


// ==========================================
// SHOW / HIDE PASSWORD
// ==========================================

function togglePassword() {

    const passwordInput =
        document.getElementById("password");


    if (passwordInput.type === "password") {

        passwordInput.type = "text";

    } else {

        passwordInput.type = "password";

    }

}