import streamlit as st
from openai import OpenAI
from pydantic import Field, SecretStr
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env", env_prefix="OPENAI_", extra="allow"
    )
    base_url: str = Field(default="")
    model: str = Field(default="")
    api_key: SecretStr = Field(default=SecretStr("abc123"))


settings = Settings()


@st.cache_resource
def get_openai_client() -> OpenAI:
    return OpenAI(
        base_url=settings.base_url, api_key=settings.api_key.get_secret_value()
    )


client = get_openai_client()

if "messages" not in st.session_state:
    st.session_state.messages = []

chat_window = st.container(height=600)
for message in st.session_state.messages:
    chat_window.chat_message(message["role"]).write(message["content"])

left, right = st.columns([7, 3])
if right.button("Reset Chat", icon=":material/sync:"):
    del st.session_state["messages"]
    st.rerun()

if prompt := left.chat_input("Say something"):
    chat_window.chat_message("user").write(prompt)
    st.session_state.messages.append({"role": "user", "content": prompt})
    chunks = client.chat.completions.create(
        model=settings.model,
        messages=st.session_state.messages,
        stream=True,
    )

    full_response = ""

    def chunks_generator():
        global full_response
        for chunk in chunks:
            delta = chunk.choices[0].delta
            if content := delta.content:
                full_response += content
                yield content

    chat_window.chat_message("assistant").write_stream(chunks_generator())
    st.session_state.messages.append({"role": "assistant", "content": full_response})
