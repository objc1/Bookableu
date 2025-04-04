const API_BASE = "";
let token = null;
let currentBook = null;
let activeFetches = 0; // Counter for active fetch requests
const TIMEOUT_MS = 15000; // 15 seconds timeout for each request
const MAX_SPINNER_TIME = 30000; // 30 seconds max spinner time

// Loading indicator functions
function showLoading() {
    const loader = document.getElementById("loading-indicator");
    loader.classList.remove("hidden");
    loader.style.display = ""; // Remove inline display style
}

function hideLoading() {
    const loader = document.getElementById("loading-indicator");
    loader.classList.add("hidden");
    loader.style.display = "none";
}

// Utility: Toggle element visibility using the "hidden" class
function toggleVisibility(element, show) {
    element.classList.toggle("hidden", !show);
}

// DOM Elements: Navigation links and Sections
const navLinks = {
    register: document.getElementById("link-register"),
    login: document.getElementById("link-login"),
    books: document.getElementById("link-books"),
    upload: document.getElementById("link-upload"),
    profile: document.getElementById("link-profile")
};

const sections = {
    register: document.getElementById("section-register"),
    login: document.getElementById("section-login"),
    books: document.getElementById("section-books"),
    upload: document.getElementById("section-upload"),
    bookDetail: document.getElementById("section-book-detail"),
    profile: document.getElementById("section-profile")
};

// Show a specific section and hide the others
function showSection(sectionToShow) {
    Object.values(sections).forEach(section => {
        toggleVisibility(section, section === sectionToShow);
    });
}

// Initialize the page
async function initializePage() {
    let logoutLink = document.getElementById("link-logout");
    if (!logoutLink) {
        logoutLink = document.createElement("a");
        logoutLink.href = "#";
        logoutLink.textContent = "Logout";
        logoutLink.className = "hidden";
        logoutLink.id = "link-logout";
        logoutLink.addEventListener("click", (e) => {
            e.preventDefault();
            logout();
        });
        document.querySelector("nav").appendChild(logoutLink);
    }

    showSection(sections.login);

    try {
        const storedToken = localStorage.getItem("token");
        if (storedToken) {
            token = storedToken;
            try {
                const response = await fetch(`${API_BASE}/users/me`, {
                    headers: { "Authorization": `Bearer ${token}` }
                });
                if (response.ok) {
                    toggleVisibility(navLinks.upload, true);
                    toggleVisibility(navLinks.books, true);
                    toggleVisibility(navLinks.profile, true);
                    toggleVisibility(navLinks.register, false);
                    toggleVisibility(navLinks.login, false);
                    toggleVisibility(logoutLink, true);
                    showSection(sections.books);
                    loadBooks();
                } else {
                    localStorage.removeItem("token");
                    token = null;
                    toggleVisibility(navLinks.register, true);
                    toggleVisibility(navLinks.login, true);
                    toggleVisibility(logoutLink, false);
                }
            } catch (error) {
                console.error("Error verifying token:", error);
                localStorage.removeItem("token");
                token = null;
                toggleVisibility(navLinks.register, true);
                toggleVisibility(navLinks.login, true);
                toggleVisibility(logoutLink, false);
            }
        } else {
            toggleVisibility(navLinks.register, true);
            toggleVisibility(navLinks.login, true);
            toggleVisibility(logoutLink, false);
        }
    } catch (error) {
        console.error("Error during initialization:", error);
        toggleVisibility(navLinks.register, true);
        toggleVisibility(navLinks.login, true);
        toggleVisibility(document.getElementById("link-logout"), false);
    }
}

// Navigation Event Listeners
navLinks.register.addEventListener("click", (e) => {
    e.preventDefault();
    showSection(sections.register);
});

navLinks.login.addEventListener("click", (e) => {
    e.preventDefault();
    showSection(sections.login);
});

navLinks.upload.addEventListener("click", (e) => {
    e.preventDefault();
    showSection(sections.upload);
});

navLinks.books.addEventListener("click", (e) => {
    e.preventDefault();
    showSection(sections.books);
    loadBooks();
});

navLinks.profile.addEventListener("click", (e) => {
    e.preventDefault();
    showSection(sections.profile);
    loadProfile();
});

document.getElementById("back-to-library").addEventListener("click", (e) => {
    e.preventDefault();
    showSection(sections.books);
});

// Registration Form Submission
document.getElementById("register-form").addEventListener("submit", async (e) => {
    e.preventDefault();
    const email = document.getElementById("reg-email").value;
    const password = document.getElementById("reg-password").value;
    const name = document.getElementById("reg-name").value;

    try {
        const response = await fetch(`${API_BASE}/auth/register`, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ email, password, name })
        });
        const data = await response.json();
        if (response.ok) {
            alert("Registration successful. Please log in.");
            showSection(sections.login);
        } else {
            alert(`Registration failed: ${data.detail || "Unknown error"}`);
        }
    } catch (error) {
        console.error("Registration error:", error);
        alert("An error occurred during registration.");
    }
});

// Login Form Submission
document.getElementById("login-form").addEventListener("submit", async (e) => {
    e.preventDefault();
    const email = document.getElementById("login-email").value;
    const password = document.getElementById("login-password").value;

    try {
        const response = await fetch(`${API_BASE}/auth/login`, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ email, password })
        });
        const data = await response.json();
        if (response.ok) {
            token = data.access_token;
            localStorage.setItem("token", token);
            loadBooks();
            const logoutLink = document.getElementById("link-logout");
            toggleVisibility(navLinks.upload, true);
            toggleVisibility(navLinks.books, true);
            toggleVisibility(navLinks.profile, true);
            toggleVisibility(navLinks.register, false);
            toggleVisibility(navLinks.login, false);
            if (logoutLink) toggleVisibility(logoutLink, true);
            showSection(sections.books);
        } else {
            alert(`Login failed: ${data.detail || "Unknown error"}`);
        }
    } catch (error) {
        console.error("Login error:", error);
        alert("An error occurred during login.");
    }
});

// Upload Book Form Submission
document.getElementById("upload-form").addEventListener("submit", async (e) => {
    e.preventDefault();
    const fileInput = document.getElementById("book-file");
    const author = document.getElementById("book-author").value;
    const totalPages = document.getElementById("book-total-pages").value;

    if (fileInput.files.length === 0) {
        alert("Please select a file.");
        return;
    }

    const formData = new FormData();
    formData.append("file", fileInput.files[0]);
    formData.append("author", author);
    formData.append("total_pages", totalPages);

    try {
        const response = await fetch(`${API_BASE}/books/upload`, {
            method: "POST",
            headers: { "Authorization": `Bearer ${token}` },
            body: formData
        });
        const data = await response.json();
        if (response.ok) {
            alert("Book uploaded successfully!");
            loadBooks();
        } else {
            alert(`Upload failed: ${data.detail || "Unknown error"}`);
        }
    } catch (error) {
        console.error("Upload error:", error);
        alert("An error occurred during book upload.");
    }
});

// Load Books and display as cards in a grid
async function loadBooks() {
    showLoading();
    const booksGrid = document.getElementById("books-grid");

    // Show loading message in the grid
    booksGrid.innerHTML = '<div class="loading-books">Loading your books...</div>';

    try {
        const response = await fetch(`${API_BASE}/books`, {
            headers: { "Authorization": `Bearer ${token}` }
        });

        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }

        const books = await response.json();

        // Clear the loading message
        booksGrid.innerHTML = "";

        if (!books || books.length === 0) {
            booksGrid.innerHTML = '<div class="no-books-message">No books found. Upload your first book!</div>';
            return;
        }

        books.forEach(book => {
            const card = document.createElement("div");
            card.className = "book-card";
            let statusClass = "status-not-started";
            if (book.status === "READING") {
                statusClass = "status-reading";
            } else if (book.status === "COMPLETED") {
                statusClass = "status-completed";
            }
            const firstLetter = (book.title || "B").charAt(0).toUpperCase();
            const progress = book.progress || 0;
            card.innerHTML = `
        <div class="book-cover">${firstLetter}</div>
        <div class="book-info">
          <div class="book-title">${book.title || "Untitled"}</div>
          <div class="book-author">${book.author || "Unknown Author"}</div>
          <div class="book-progress-bar">
            <div class="book-progress-fill" style="width: ${progress}%"></div>
          </div>
          <span class="book-status ${statusClass}">${book.status || "Not Started"}</span>
        </div>
      `;
            card.addEventListener("click", async () => {
                openBook(book);
            });
            booksGrid.appendChild(card);
        });
    } catch (error) {
        console.error("Error loading books:", error);
        booksGrid.innerHTML = '<div class="no-books-message">Error loading books. Please try again later.</div>';
    } finally {
        hideLoading();
    }
}

async function openBook(book) {
    currentBook = book;
    try {
        showLoading();
        const downloadResponse = await fetch(`${API_BASE}/books/download/${book.id}`, {
            headers: { "Authorization": `Bearer ${token}` }
        });

        if (!downloadResponse.ok) {
            throw new Error(`HTTP error! status: ${downloadResponse.status}`);
        }

        const downloadData = await downloadResponse.json();
        if (downloadData.download_url) {
            showSection(sections.bookDetail);
            document.getElementById("book-title").textContent = book.title || "Untitled";
            const progress = book.progress || 0;
            document.getElementById("book-progress").textContent = `Progress: ${progress}%`;
            document.getElementById("book-progress-fill").style.width = `${progress}%`;
            const originalUrl = downloadData.download_url;

            const bookViewer = document.getElementById("book-viewer");
            const pdfViewer = document.getElementById("pdf-viewer");
            const pdfDownloadLink = document.getElementById("pdf-download-link");

            if (originalUrl.toLowerCase().endsWith('.pdf')) {
                try {
                    const pdfResponse = await fetch(originalUrl);
                    if (!pdfResponse.ok) {
                        throw new Error(`HTTP error! status: ${pdfResponse.status}`);
                    }
                    const pdfBlob = await pdfResponse.blob();
                    const blobUrl = URL.createObjectURL(pdfBlob);
                    pdfViewer.data = blobUrl;
                    pdfDownloadLink.href = blobUrl;
                    toggleVisibility(bookViewer, false);
                    toggleVisibility(pdfViewer, true);
                } catch (error) {
                    console.error("Error fetching PDF:", error);
                    alert("Error loading PDF. Please try opening it in a new tab.");
                    pdfDownloadLink.href = originalUrl;
                    toggleVisibility(bookViewer, false);
                    toggleVisibility(pdfViewer, true);
                }
            } else {
                bookViewer.src = originalUrl;
                toggleVisibility(bookViewer, true);
                toggleVisibility(pdfViewer, false);
            }
        } else {
            alert("Download URL not available");
        }
    } catch (err) {
        console.error("Download error:", err);
        alert("Error fetching download URL");
    } finally {
        hideLoading();
    }
}

// Update book progress
async function updateBookProgress(progress) {
    if (!currentBook) return;
    try {
        const response = await fetch(`${API_BASE}/books/${currentBook.id}/progress`, {
            method: "PUT",
            headers: {
                "Content-Type": "application/json",
                "Authorization": `Bearer ${token}`
            },
            body: JSON.stringify({ progress })
        });
        if (response.ok) {
            document.getElementById("book-progress").textContent = `Progress: ${progress}%`;
            document.getElementById("book-progress-fill").style.width = `${progress}%`;
        }
    } catch (error) {
        console.error("Error updating progress:", error);
    }
}

document.getElementById("book-viewer").addEventListener("load", function () {
    window.addEventListener("message", function (event) {
        if (event.data.type === "progress") {
            updateBookProgress(event.data.progress);
        }
    });
});

document.getElementById("fullscreen-btn").addEventListener("click", function () {
    const viewer = document.getElementById("book-viewer");
    const pdfViewer = document.getElementById("pdf-viewer");
    const viewerContainer = document.querySelector(".book-viewer-container");

    const isPdfActive = !pdfViewer.classList.contains("hidden");
    const viewerType = isPdfActive ? 'pdf' : (viewer.getAttribute('data-type') || 'epub');

    let elementToFullscreen;
    if (isPdfActive) {
        elementToFullscreen = viewerContainer;
    } else if (viewerType === 'pdf-js') {
        elementToFullscreen = viewerContainer;
    } else {
        elementToFullscreen = viewer;
    }

    if (document.fullscreenElement) {
        document.exitFullscreen()
            .catch(err => console.error(`Error exiting fullscreen: ${err.message}`));
    } else {
        elementToFullscreen.requestFullscreen()
            .catch(err => console.error(`Error entering fullscreen: ${err.message}`));
    }
});

document.addEventListener("fullscreenchange", function () {
    const fullscreenBtn = document.getElementById("fullscreen-btn");
    if (document.fullscreenElement) {
        fullscreenBtn.innerHTML = `
      <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        <path d="M4 14h6m0 0v6m0-6l-7 7m17-11h-6m0 0V4m0 6l7-7"></path>
      </svg>
    `;
    } else {
        fullscreenBtn.innerHTML = `
      <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        <path d="M8 3H5a2 2 0 0 0-2 2v3m18 0V5a2 2 0 0 0-2-2h-3m0 18h3a2 2 0 0 0 2-2v-3M3 16v3a2 2 0 0 0 2 2h3"></path>
      </svg>
    `;
    }
});

async function loadProfile() {
    try {
        const response = await fetch(`${API_BASE}/users/me`, {
            headers: { "Authorization": `Bearer ${token}` }
        });

        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }

        const profile = await response.json();
        const profileInfo = document.getElementById("profile-info");
        profileInfo.innerHTML = `
      <p><strong>Email:</strong> ${profile.email}</p>
      <p><strong>Name:</strong> ${profile.name || "Not set"}</p>
      <p><strong>Books Finished:</strong> ${profile.books_finished || 0}</p>
    `;

        if (profile.profile_picture) {
            const picResponse = await fetch(`${API_BASE}/users/me/picture-url`, {
                headers: { "Authorization": `Bearer ${token}` }
            });

            if (!picResponse.ok) {
                throw new Error(`HTTP error! status: ${picResponse.status}`);
            }

            const picData = await picResponse.json();
            const profilePic = document.getElementById("profile-picture-img");
            if (picData.url) {
                profilePic.src = picData.url;
                toggleVisibility(profilePic, true);
            } else {
                toggleVisibility(profilePic, false);
            }
        } else {
            toggleVisibility(document.getElementById("profile-picture-img"), false);
        }
    } catch (error) {
        console.error("Error loading profile:", error);
        document.getElementById("profile-info").innerHTML = "<p>Error loading profile. Please try again.</p>";
    }
}

document.getElementById("profile-form").addEventListener("submit", async (e) => {
    e.preventDefault();
    const name = document.getElementById("profile-name").value;
    const pictureInput = document.getElementById("profile-picture");

    const formData = new FormData();
    if (name) {
        formData.append("name", name);
    }
    if (pictureInput.files.length > 0) {
        formData.append("picture", pictureInput.files[0]);
    }

    try {
        const response = await fetch(`${API_BASE}/users/me`, {
            method: "PUT",
            headers: { "Authorization": `Bearer ${token}` },
            body: formData
        });
        const data = await response.json();
        if (response.ok) {
            alert("Profile updated successfully!");
            loadProfile();
        } else {
            alert(`Profile update failed: ${data.detail || "Unknown error"}`);
        }
    } catch (error) {
        console.error("Profile update error:", error);
        alert("An error occurred while updating profile.");
    }
});

function logout() {
    token = null;
    localStorage.removeItem("token");
    toggleVisibility(navLinks.upload, false);
    toggleVisibility(navLinks.books, false);
    toggleVisibility(navLinks.profile, false);
    toggleVisibility(navLinks.register, true);
    toggleVisibility(navLinks.login, true);

    const logoutLink = document.getElementById("link-logout");
    if (logoutLink) {
        toggleVisibility(logoutLink, false);
    }
    showSection(sections.login);
}

// Updated fetch override with request counter, timeout, and max spinner timer
const originalFetch = window.fetch;
window.fetch = function (url, options = {}) {
    activeFetches++;
    if (activeFetches === 1) {
        showLoading();
        // Set a maximum time to hide the spinner if something goes wrong
        setTimeout(() => {
            if (activeFetches > 0) {
                console.warn("Max spinner time reached. Resetting spinner.");
                activeFetches = 0;
                hideLoading();
            }
        }, MAX_SPINNER_TIME);
    }

    // Setup timeout if no signal is provided
    let timeoutId;
    if (!options.signal) {
        const controller = new AbortController();
        options.signal = controller.signal;
        timeoutId = setTimeout(() => {
            controller.abort();
        }, TIMEOUT_MS);
    }

    if (token && !options.headers) {
        options.headers = {
            "Authorization": `Bearer ${token}`
        };
    } else if (token && options.headers && !options.headers.Authorization) {
        options.headers = {
            ...options.headers,
            "Authorization": `Bearer ${token}`
        };
    }

    return originalFetch(url, options)
        .then(response => {
            if (response.status === 401) {
                logout();
                alert("Your session has expired. Please log in again.");
            }
            return response;
        })
        .catch(error => {
            console.error("API request failed:", error);
            throw error;
        })
        .finally(() => {
            if (timeoutId) {
                clearTimeout(timeoutId);
            }
            activeFetches--;
            if (activeFetches === 0) {
                hideLoading();
            }
        });
};

document.addEventListener("DOMContentLoaded", function () {
    hideLoading(); // Hide spinner immediately
    initializePage(); // Proceed with initialization
});