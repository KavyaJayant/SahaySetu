// ==========================================
// SAHAYSETU - ADMINISTRATION LOGIN
// ==========================================


// BACKEND URL

const API_URL = "http://127.0.0.1:8000";


// LOGIN FORM

const loginForm =
    document.getElementById("loginForm");


// ==========================================
// LOGIN
// ==========================================

loginForm.addEventListener(
    "submit",
    async function(event) {

        event.preventDefault();


        // Get values

        const login =
            document
                .getElementById("login")
                .value
                .trim();


        const password =
            document
                .getElementById("password")
                .value;


        // Check empty fields

        if (
            login === "" ||
            password === ""
        ) {

            alert(
                "Please enter your Email ID/Phone Number and Password."
            );

            return;
        }


        // Login button

        const loginButton =
            document.getElementById(
                "loginButton"
            );


        loginButton.disabled = true;

        loginButton.textContent =
            "Logging in...";


        try {

            // ======================================
            // LOGIN REQUEST
            // ======================================

            
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


            // ======================================
            // RESPONSE
            // ======================================

            const data =
                await response.json();


            console.log(
                "Administration login response:",
                data
            );


            // ======================================
            // LOGIN FAILED
            // ======================================

            if (!response.ok) {

                alert(
                    data.detail ||
                    "Login failed. Please check your credentials."
                );


                loginButton.disabled = false;

                loginButton.textContent =
                    "Login";

                return;
            }


            // ======================================
            // TOKEN
            // ======================================

            if (
                !data.access_token
            ) {

                alert(
                    "Login successful, but no access token was received."
                );


                loginButton.disabled = false;

                loginButton.textContent =
                    "Login";

                return;
            }


            // ======================================
            // SAVE TOKEN
            // ======================================

            localStorage.setItem(
                "access_token",
                data.access_token
            );


            localStorage.setItem(
                "admin_login",
                login
            );


            // ======================================
            // GO TO ADMIN DASHBOARD
            // ======================================

            window.location.href =
                "administration.html";

        }


        catch(error) {

            console.error(
                "Login error:",
                error
            );


            alert(
                "Cannot connect to the SahaySetu backend.\n\n" +
                "Make sure the FastAPI server is running."
            );


            loginButton.disabled = false;

            loginButton.textContent =
                "Login";

        }

    }
);


// ==========================================
// SHOW / HIDE PASSWORD
// ==========================================

function togglePassword() {

    const passwordInput =
        document.getElementById(
            "password"
        );


    if (
        passwordInput.type ===
        "password"
    ) {

        passwordInput.type =
            "text";

    }

    else {

        passwordInput.type =
            "password";

    }

}