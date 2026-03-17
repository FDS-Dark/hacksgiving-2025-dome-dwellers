from fastapi import APIRouter
from pydantic import BaseModel

# Try to load chatbot
CHAT_BOT_WORKS = False
OPENAI_API_KEY = ""

try:
    import openai

    from settings import config
    oai_api_key = config.openai.api_key
    if oai_api_key.startswith("sk-"):
        OPENAI_API_KEY = oai_api_key
        CHAT_BOT_WORKS = True
    else:
        print("WARNING: OpenAI API key not found or invalid in settings!")
        
except:
    print("WARNING: OpenAI Library not found! To use the chat features, make sure its installed.")


# Try to load content
CONTEXT = ""
try:
    with open("chat_context.txt", "r", encoding="utf-8") as f:
        CONTEXT = f.read()
except Exception as e:
    print("WARNING: chat_context.txt file not found! Continuing without context.")
    print(e)
    import os
    print("Current working directory:", os.getcwd())

router = APIRouter(prefix="/chat", tags=["chat"])

MOOD_OPTIONS = {
    "Critical": "You carefully analyze and critique ideas pointing out potential flaws and weaknesses in approaches to help provide constructive feedback.",
    "Creative": "You think outside the box and come up with radical and innovative ideas that break from traditional approaches to help inspire new directions.",
    "Optimistic": "You provide positive and encouraging ideas that focus on potential benefits and opportunities to help uplift and motivate.",
    "Pirate": "You respond like a stereotypical pirate, using nautical terms and pirate slang to add a fun and adventurous tone to your ideas.",
}

class ChatMessage(BaseModel):
    message: str
    mood: str

class ChatResponse(BaseModel):
    response: str

@router.post("/response")
async def chat_response(message: ChatMessage):
    # Implement your chat logic here
    if not CHAT_BOT_WORKS:
        return ChatResponse(response="Chat functionality is currently unavailable. Please check API configuration.")
    if CONTEXT == "":
        return ChatResponse(response="I am lobotomized and cannot respond at this time.")
    else:
        client = openai.Client(api_key=OPENAI_API_KEY)
        responses = client.chat.completions.create(
            model="gpt-5.1",
            messages=[
                {"role": "user", "content": "Given the following context, answer the user's question. Make your response very brief.\n\nContext:\n" + CONTEXT + "\n\nUser Info: The user is from the Mitchell Domes and will likely ask questions about other botanical gardens to help improve the Mitchell Domes in Milwaukee.\n\nChat Bot Person (" + MOOD_OPTIONS[message.mood] + ")\n\nQuestion: " + message.message}
            ]
        )

        response_text = responses.choices[0].message.content
        return ChatResponse(response=response_text)