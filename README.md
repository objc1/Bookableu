# 📖 Bookableu

Bookableu is an AI-powered reading assistant designed to enhance the reading experience. It works with **e-books (PDF, EPUB, etc.)** and integrates an **AI model** to help users summarize content and answer questions based on their reading material.

## 🚀 Features

- 📚 **AI-powered Reading Assistant** – Ask questions and get instant answers based on the book you're reading.
- 📝 **Smart Summaries** – Get AI-generated summaries of chapters or sections.
- 🔍 **Multi-format Support** – Works with **PDF, EPUB, and other popular formats**.
- ☁ **Cloud Integration** – Future plans to host the project on **AWS**.

## 🛠️ Tech Stack

- **AI & Machine Learning**: Open-source **LLM (Large Language Model)**
- **Backend**: Python, Flask/FastAPI (to connect AI model)
- **Frontend**: iOS (Swift, SwiftUI)
- **Database**: PostgreSQL (TBD)
- **Hosting**: AWS / Vercel (TBD)
- **Version Control**: Git & GitHub

## 📂 Project Roadmap

✅ **Phase 1 (Weeks 1-5):**  
- Research AI models & set up tools  
- Create GitHub repository  
- Define the tech stack  

🔄 **Phase 2 (Weeks 6-7):**  
- Develop a **working AI pipeline** (fetch text → prepare → process request-response)  
- MVP of the AI assistant  

🔜 **Phase 3 (Weeks 8-12):**  
- Build frontend (Website or Mobile App)  
- Connect AI pipeline via API  
- Improve AI responses & UX  

## 🔧 Installation (For Developers)

1. **Clone this repository**  
   ```bash
   git clone git@github.com:objc1/Bookableu.git
   cd bookableu
   ```
2. TBA

## FAQ
Q: Why is iOS the main platform for this project? <br>
A: I have the most experience with iOS development, so it makes the most sense for me to start there. It allows me to build and iterate more efficiently.

Q: Will the LLM be integrated locally or via an API? <br>
A: For now, I’m leaning toward using an API since it’s easier to implement and maintain in the early stages of the project.

Q: What makes Bookableu different from other reading apps? <br>
A: Unlike standard e-book readers, Bookableu integrates AI to enhance the reading experience. It helps with summaries, explanations, and answering questions directly based on the book’s content, making reading more engaging and interactive.

Q: What AI model will you use? <br>
A: I plan to use an API like OpenAI’s GPT, Google Gemini, Anthropic Claude, depending on performance, cost, and feasibility. If I decide to have an integrated local model it will be an open-source LLM. For example: Mistral 7B, LLaMA 3, Google Gemma.

Q: Will there be a web version of Bookableu? <br>
A: Possibly! While iOS is the main platform for now, I’m considering developing a web or cross-platform mobile version later using React.js or Flutter.

Q: Will Bookableu support multiple languages? <br>
A: Initially, it will focus on English, but adding support for French, Spanish, and other languages is definitely something I’d like to explore.

Q: Will this project remain open-source? <br>
A: Right now, it’s a personal project, but I’m open to collaboration and contributions in the future.
