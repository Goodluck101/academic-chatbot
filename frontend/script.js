class AcademicChatbot {
    constructor() {
        this.apiUrl = null;
        this.apiKey = 'H9zgry8uFN6wmONIAm5koaS19qZy63Yz48bsb6yc'; // API key stored as instance variable
        this.initializeEventListeners();
        this.loadConfig();
    }

    async loadConfig() {
        try {
            // First try to load from config.json
            await this.loadFromConfigFile();
            
            // If still no URL, use fallback
            if (!this.apiUrl) {
                this.useFallbackConfig();
            }
            
        } catch (error) {
            this.useFallbackConfig();
        }
    }

    async loadFromConfigFile() {
        try {
            const response = await fetch('./config.json');
            if (response.ok) {
                const config = await response.json();
                if (config.API_GATEWAY_URL) {
                    this.apiUrl = config.API_GATEWAY_URL;
                }
            } else {
                throw new Error('Config file not found or inaccessible');
            }
        } catch (error) {
            // Silent fail - use fallback config
        }
    }

    useFallbackConfig() {
        // Use your actual API Gateway URL as the fallback
        this.apiUrl = 'https://27pwk19u97.execute-api.us-east-1.amazonaws.com/dev/chat';
    }

    initializeEventListeners() {
        const sendBtn = document.getElementById('send-btn');
        const userInput = document.getElementById('user-input');

        if (sendBtn && userInput) {
            sendBtn.addEventListener('click', () => this.sendMessage());
            
            userInput.addEventListener('keypress', (e) => {
                if (e.key === 'Enter') {
                    this.sendMessage();
                }
            });
        }
    }

    async sendMessage() {
        const userInput = document.getElementById('user-input');
        const message = userInput.value.trim();
        
        if (!message) return;

        // Add user message to chat
        this.addMessage(message, 'user');
        userInput.value = '';
        
        // Show loading
        this.showLoading(true);
        
        try {
            const response = await this.callAPI(message);
            this.addMessage(response, 'bot');
        } catch (error) {
            this.addMessage('Sorry, I encountered an error while processing your request. Please try again.', 'bot');
        } finally {
            this.showLoading(false);
        }
    }

    async callAPI(message) {
        if (!this.apiUrl) {
            throw new Error('API URL is not configured');
        }
        
        const response = await fetch(this.apiUrl, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'x-api-key': this.apiKey // Add API key header
            },
            body: JSON.stringify({
                message: message
            })
        });
        
        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }

        const data = await response.json();
        return data.response;
    }

    addMessage(text, sender) {
        const chatMessages = document.getElementById('chat-messages');
        if (!chatMessages) {
            return;
        }
        
        const messageDiv = document.createElement('div');
        
        messageDiv.className = `message ${sender}-message`;
        messageDiv.innerHTML = `<p>${this.escapeHtml(text)}</p>`;
        
        chatMessages.appendChild(messageDiv);
        chatMessages.scrollTop = chatMessages.scrollHeight;
    }

    showLoading(show) {
        const loading = document.getElementById('loading');
        const sendBtn = document.getElementById('send-btn');
        
        if (loading && sendBtn) {
            if (show) {
                loading.style.display = 'block';
                sendBtn.disabled = true;
                sendBtn.innerHTML = '<span>Sending...</span>';
            } else {
                loading.style.display = 'none';
                sendBtn.disabled = false;
                sendBtn.innerHTML = '<span>Send</span><svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor"><path d="M2.01 21L23 12 2.01 3 2 10l15 2-15 2z"/></svg>';
            }
        }
    }

    escapeHtml(text) {
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }

    // Method to update API URL dynamically
    setApiUrl(url) {
        this.apiUrl = url;
    }
}

// Initialize chatbot when page loads
document.addEventListener('DOMContentLoaded', () => {
    window.chatbot = new AcademicChatbot();
});



// class AcademicChatbot {
//     constructor() {
//         this.apiUrl = null;
//         this.initializeEventListeners();
//         this.loadConfig();
//     }

//     async loadConfig() {
//         try {
//             // First try to load from config.json
//             await this.loadFromConfigFile();
            
//             // If still no URL, use fallback
//             if (!this.apiUrl) {
//                 this.useFallbackConfig();
//             }
            
//             console.log('API URL loaded:', this.apiUrl);
//             this.updateApiInfo();
            
//         } catch (error) {
//             console.warn('Could not load configuration:', error);
//             this.useFallbackConfig();
//         }
//     }

//     async loadFromConfigFile() {
//         try {
//             const response = await fetch('./config.json');
//             if (response.ok) {
//                 const config = await response.json();
//                 if (config.API_GATEWAY_URL) {
//                     this.apiUrl = config.API_GATEWAY_URL;
//                     console.log('Loaded API URL from config.json:', this.apiUrl);
//                 }
//             } else {
//                 throw new Error('Config file not found or inaccessible');
//             }
//         } catch (error) {
//             console.warn('Could not load from config.json:', error);
//             // Don't throw here, let the fallback handle it
//         }
//     }

//     useFallbackConfig() {
//         // Use your actual API Gateway URL as the fallback
//         this.apiUrl = 'https://27pwk19u97.execute-api.us-east-1.amazonaws.com/dev/chat';
//         console.warn('Using fallback API URL:', this.apiUrl);
//     }

//     initializeEventListeners() {
//         const sendBtn = document.getElementById('send-btn');
//         const userInput = document.getElementById('user-input');

//         if (sendBtn && userInput) {
//             sendBtn.addEventListener('click', () => this.sendMessage());
            
//             userInput.addEventListener('keypress', (e) => {
//                 if (e.key === 'Enter') {
//                     this.sendMessage();
//                 }
//             });
//         } else {
//             console.error('Could not find send button or user input element');
//         }
//     }

//     updateApiInfo() {
//         // Display API info for debugging
//         if (window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1' || window.location.hostname === '') {
//             console.log('Current API Endpoint:', this.apiUrl);
            
//             // Add visual indicator in development
//             const existingInfo = document.querySelector('.api-info');
//             if (existingInfo) {
//                 existingInfo.remove();
//             }
            
//             const infoDiv = document.createElement('div');
//             infoDiv.className = 'api-info';
//             infoDiv.style.cssText = 'background: #e3f2fd; color: #1565c0; padding: 8px; margin: 10px; border-radius: 5px; font-size: 12px; border-left: 4px solid #2196f3;';
//             infoDiv.innerHTML = `<strong>Development Mode</strong><br>API: ${this.apiUrl}<br>Open browser console (F12) for detailed logs`;
            
//             const chatContainer = document.querySelector('.chat-container');
//             if (chatContainer) {
//                 chatContainer.prepend(infoDiv);
//             }
//         }
//     }

//     async sendMessage() {
//         const userInput = document.getElementById('user-input');
//         const message = userInput.value.trim();
        
//         if (!message) return;

//         // Add user message to chat
//         this.addMessage(message, 'user');
//         userInput.value = '';
        
//         // Show loading
//         this.showLoading(true);
        
//         try {
//             console.log('Sending message to:', this.apiUrl);
//             const response = await this.callAPI(message);
//             this.addMessage(response, 'bot');
//         } catch (error) {
//             console.error('API Call Error:', error);
//             this.addMessage('Sorry, I encountered an error. Please check the browser console for details.', 'bot');
//             this.showErrorDetails(error);
//         } finally {
//             this.showLoading(false);
//         }
//     }

//     async callAPI(message) {
//         if (!this.apiUrl) {
//             throw new Error('API URL is not configured');
//         }

//         console.log('Making API call to:', this.apiUrl);
        
//         const response = await fetch(this.apiUrl, {
//             method: 'POST',
//             headers: {
//                 'Content-Type': 'application/json',
//             },
//             body: JSON.stringify({
//                 message: message
//             })
//         });

//         console.log('Response status:', response.status);
        
//         if (!response.ok) {
//             const errorText = await response.text();
//             console.error('API Error Response:', errorText);
//             throw new Error(`HTTP error! status: ${response.status}. Endpoint: ${this.apiUrl}`);
//         }

//         const data = await response.json();
//         console.log('API Success Response:', data);
//         return data.response;
//     }

//     addMessage(text, sender) {
//         const chatMessages = document.getElementById('chat-messages');
//         if (!chatMessages) {
//             console.error('Chat messages container not found');
//             return;
//         }
        
//         const messageDiv = document.createElement('div');
        
//         messageDiv.className = `message ${sender}-message`;
//         messageDiv.innerHTML = `<p>${this.escapeHtml(text)}</p>`;
        
//         chatMessages.appendChild(messageDiv);
//         chatMessages.scrollTop = chatMessages.scrollHeight;
//     }

//     // showLoading(show) {
//     //     const loading = document.getElementById('loading');
//     //     const sendBtn = document.getElementById('send-btn');
        
//     //     if (loading && sendBtn) {
//     //         if (show) {
//     //             loading.style.display = 'block';
//     //             sendBtn.disabled = true;
//     //             sendBtn.textContent = 'Sending...';
//     //         } else {
//     //             loading.style.display = 'none';
//     //             sendBtn.disabled = false;
//     //             sendBtn.textContent = 'Send';
//     //         }
//     //     }
//     // }

//     showLoading(show) {
//     const loading = document.getElementById('loading');
//     const sendBtn = document.getElementById('send-btn');
    
//     if (loading && sendBtn) {
//         if (show) {
//             loading.style.display = 'block';
//             sendBtn.disabled = true;
//             sendBtn.innerHTML = '<span>Sending...</span>';
//         } else {
//             loading.style.display = 'none';
//             sendBtn.disabled = false;
//             sendBtn.innerHTML = '<span>Send</span><svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor"><path d="M2.01 21L23 12 2.01 3 2 10l15 2-15 2z"/></svg>';
//         }
//     }
// }

//     showErrorDetails(error) {
//         // Show detailed errors in development
//         if (window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1' || window.location.hostname === '') {
//             const errorDiv = document.createElement('div');
//             errorDiv.className = 'message error-message';
//             errorDiv.style.background = '#ffebee';
//             errorDiv.style.color = '#c62828';
//             errorDiv.style.borderLeft = '4px solid #f44336';
//             errorDiv.innerHTML = `
//                 <p><strong>Debug Info:</strong></p>
//                 <p>Error: ${this.escapeHtml(error.message)}</p>
//                 <p>Check browser console (F12) for details</p>
//             `;
//             const chatMessages = document.getElementById('chat-messages');
//             if (chatMessages) {
//                 chatMessages.appendChild(errorDiv);
//                 chatMessages.scrollTop = chatMessages.scrollHeight;
//             }
//         }
//     }

//     escapeHtml(text) {
//         const div = document.createElement('div');
//         div.textContent = text;
//         return div.innerHTML;
//     }

//     // Method to update API URL dynamically
//     setApiUrl(url) {
//         this.apiUrl = url;
//         console.log('API URL updated to:', url);
//         this.updateApiInfo();
//     }
// }

// // Initialize chatbot when page loads
// document.addEventListener('DOMContentLoaded', () => {
//     console.log('Initializing Academic Chatbot...');
//     window.chatbot = new AcademicChatbot();
// });



// // class AcademicChatbot {
// //     constructor() {
// //         this.loadConfig();
// //         this.initializeEventListeners();
// //     }

// //     async loadConfig() {
// //         try {
// //             // In a real application, you might load this from a config file
// //             // For now, we'll use a fallback mechanism
// //             this.apiUrl = window.API_URL || 'https://your-api-gateway-url.execute-api.us-east-1.amazonaws.com/prod/chat';
            
// //             // You can also load from a config file
// //             await this.loadFromConfigFile();
// //         } catch (error) {
// //             console.warn('Could not load configuration:', error);
// //             this.useFallbackConfig();
// //         }
// //     }

// //     async loadFromConfigFile() {
// //         try {
// //             const response = await fetch('./config.json');
// //             if (response.ok) {
// //                 const config = await response.json();
// //                 this.apiUrl = config.API_GATEWAY_URL;
// //             }
// //         } catch (error) {
// //             console.warn('Config file not found, using environment variables');
// //         }
// //     }

// //     useFallbackConfig() {
// //         // Try to get from meta tags or data attributes
// //         const metaApiUrl = document.querySelector('meta[name="api-url"]');
// //         if (metaApiUrl) {
// //             this.apiUrl = metaApiUrl.getAttribute('content');
// //         }
        
// //         // Final fallback
// //         if (!this.apiUrl) {
// //             this.apiUrl = 'https://your-api-gateway-url.execute-api.us-east-1.amazonaws.com/prod/chat';
// //         }
// //     }

// //     initializeEventListeners() {
// //         const sendBtn = document.getElementById('send-btn');
// //         const userInput = document.getElementById('user-input');

// //         sendBtn.addEventListener('click', () => this.sendMessage());
        
// //         userInput.addEventListener('keypress', (e) => {
// //             if (e.key === 'Enter') {
// //                 this.sendMessage();
// //             }
// //         });

// //         // Update API URL display if needed
// //         this.updateApiInfo();
// //     }

// //     updateApiInfo() {
// //         // You can display the API endpoint for debugging
// //         if (window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1') {
// //             console.log('API Endpoint:', this.apiUrl);
// //         }
// //     }

// //     async sendMessage() {
// //         const userInput = document.getElementById('user-input');
// //         const message = userInput.value.trim();
        
// //         if (!message) return;

// //         // Add user message to chat
// //         this.addMessage(message, 'user');
// //         userInput.value = '';
        
// //         // Show loading
// //         this.showLoading(true);
        
// //         try {
// //             const response = await this.callAPI(message);
// //             this.addMessage(response, 'bot');
// //         } catch (error) {
// //             console.error('Error:', error);
// //             this.addMessage('Sorry, I encountered an error. Please check if the API endpoint is correctly configured.', 'bot');
// //             this.showErrorDetails(error);
// //         } finally {
// //             this.showLoading(false);
// //         }
// //     }

// //     async callAPI(message) {
// //         const response = await fetch(this.apiUrl, {
// //             method: 'POST',
// //             headers: {
// //                 'Content-Type': 'application/json',
// //             },
// //             body: JSON.stringify({
// //                 message: message
// //             })
// //         });

// //         if (!response.ok) {
// //             throw new Error(`HTTP error! status: ${response.status}. Endpoint: ${this.apiUrl}`);
// //         }

// //         const data = await response.json();
// //         return data.response;
// //     }

// //     addMessage(text, sender) {
// //         const chatMessages = document.getElementById('chat-messages');
// //         const messageDiv = document.createElement('div');
        
// //         messageDiv.className = `message ${sender}-message`;
// //         messageDiv.innerHTML = `<p>${this.escapeHtml(text)}</p>`;
        
// //         chatMessages.appendChild(messageDiv);
// //         chatMessages.scrollTop = chatMessages.scrollHeight;
// //     }

// //     showLoading(show) {
// //         const loading = document.getElementById('loading');
// //         const sendBtn = document.getElementById('send-btn');
        
// //         if (show) {
// //             loading.style.display = 'block';
// //             sendBtn.disabled = true;
// //             sendBtn.textContent = 'Sending...';
// //         } else {
// //             loading.style.display = 'none';
// //             sendBtn.disabled = false;
// //             sendBtn.textContent = 'Send';
// //         }
// //     }

// //     showErrorDetails(error) {
// //         // Only show detailed errors in development
// //         if (window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1') {
// //             const errorDiv = document.createElement('div');
// //             errorDiv.className = 'message error-message';
// //             errorDiv.innerHTML = `<p><strong>Debug Info:</strong> ${this.escapeHtml(error.message)}</p>`;
// //             document.getElementById('chat-messages').appendChild(errorDiv);
// //         }
// //     }

// //     escapeHtml(text) {
// //         const div = document.createElement('div');
// //         div.textContent = text;
// //         return div.innerHTML;
// //     }

// //     // Method to update API URL dynamically
// //     setApiUrl(url) {
// //         this.apiUrl = url;
// //         this.updateApiInfo();
// //     }
// // }

// // // Configuration loader
// // class ConfigLoader {
// //     static async load() {
// //         try {
// //             const response = await fetch('/config.json');
// //             return await response.json();
// //         } catch (error) {
// //             console.warn('Could not load config.json, using defaults');
// //             return {};
// //         }
// //     }
// // }

// // // Initialize chatbot when page loads
// // document.addEventListener('DOMContentLoaded', async () => {
// //     // Load configuration first
// //     const config = await ConfigLoader.load();
    
// //     // Initialize chatbot with config
// //     window.chatbot = new AcademicChatbot();
    
// //     // Update API URL if provided in config
// //     if (config.API_GATEWAY_URL) {
// //         window.chatbot.setApiUrl(config.API_GATEWAY_URL);
// //     }
// // });
