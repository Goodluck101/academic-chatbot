class AcademicChatbot {
    constructor() {
        this.loadConfig();
        this.initializeEventListeners();
    }

    async loadConfig() {
        try {
            // In a real application, you might load this from a config file
            // For now, we'll use a fallback mechanism
            this.apiUrl = window.API_URL || 'https://your-api-gateway-url.execute-api.us-east-1.amazonaws.com/prod/chat';
            
            // You can also load from a config file
            await this.loadFromConfigFile();
        } catch (error) {
            console.warn('Could not load configuration:', error);
            this.useFallbackConfig();
        }
    }

    async loadFromConfigFile() {
        try {
            const response = await fetch('./config.json');
            if (response.ok) {
                const config = await response.json();
                this.apiUrl = config.API_GATEWAY_URL;
            }
        } catch (error) {
            console.warn('Config file not found, using environment variables');
        }
    }

    useFallbackConfig() {
        // Try to get from meta tags or data attributes
        const metaApiUrl = document.querySelector('meta[name="api-url"]');
        if (metaApiUrl) {
            this.apiUrl = metaApiUrl.getAttribute('content');
        }
        
        // Final fallback
        if (!this.apiUrl) {
            this.apiUrl = 'https://your-api-gateway-url.execute-api.us-east-1.amazonaws.com/prod/chat';
        }
    }

    initializeEventListeners() {
        const sendBtn = document.getElementById('send-btn');
        const userInput = document.getElementById('user-input');

        sendBtn.addEventListener('click', () => this.sendMessage());
        
        userInput.addEventListener('keypress', (e) => {
            if (e.key === 'Enter') {
                this.sendMessage();
            }
        });

        // Update API URL display if needed
        this.updateApiInfo();
    }

    updateApiInfo() {
        // You can display the API endpoint for debugging
        if (window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1') {
            console.log('API Endpoint:', this.apiUrl);
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
            console.error('Error:', error);
            this.addMessage('Sorry, I encountered an error. Please check if the API endpoint is correctly configured.', 'bot');
            this.showErrorDetails(error);
        } finally {
            this.showLoading(false);
        }
    }

    async callAPI(message) {
        const response = await fetch(this.apiUrl, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                message: message
            })
        });

        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}. Endpoint: ${this.apiUrl}`);
        }

        const data = await response.json();
        return data.response;
    }

    addMessage(text, sender) {
        const chatMessages = document.getElementById('chat-messages');
        const messageDiv = document.createElement('div');
        
        messageDiv.className = `message ${sender}-message`;
        messageDiv.innerHTML = `<p>${this.escapeHtml(text)}</p>`;
        
        chatMessages.appendChild(messageDiv);
        chatMessages.scrollTop = chatMessages.scrollHeight;
    }

    showLoading(show) {
        const loading = document.getElementById('loading');
        const sendBtn = document.getElementById('send-btn');
        
        if (show) {
            loading.style.display = 'block';
            sendBtn.disabled = true;
            sendBtn.textContent = 'Sending...';
        } else {
            loading.style.display = 'none';
            sendBtn.disabled = false;
            sendBtn.textContent = 'Send';
        }
    }

    showErrorDetails(error) {
        // Only show detailed errors in development
        if (window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1') {
            const errorDiv = document.createElement('div');
            errorDiv.className = 'message error-message';
            errorDiv.innerHTML = `<p><strong>Debug Info:</strong> ${this.escapeHtml(error.message)}</p>`;
            document.getElementById('chat-messages').appendChild(errorDiv);
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
        this.updateApiInfo();
    }
}

// Configuration loader
class ConfigLoader {
    static async load() {
        try {
            const response = await fetch('/config.json');
            return await response.json();
        } catch (error) {
            console.warn('Could not load config.json, using defaults');
            return {};
        }
    }
}

// Initialize chatbot when page loads
document.addEventListener('DOMContentLoaded', async () => {
    // Load configuration first
    const config = await ConfigLoader.load();
    
    // Initialize chatbot with config
    window.chatbot = new AcademicChatbot();
    
    // Update API URL if provided in config
    if (config.API_GATEWAY_URL) {
        window.chatbot.setApiUrl(config.API_GATEWAY_URL);
    }
});
