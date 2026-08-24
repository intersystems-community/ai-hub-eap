package com.intersystems.demo;

import java.sql.DriverManager;
import java.sql.SQLException;

import com.intersystems.jdbc.IRISConnection;
import com.intersystems.llm.IRISChatModel;

import dev.langchain4j.service.AiServices;
import dev.langchain4j.service.SystemMessage;

public class LangChain4JDemo {

    public static void main(String[] args) throws Exception {
        LangChain4JDemo demo = new LangChain4JDemo();
        demo.chat();
    }

    private IRISConnection connection;

    public LangChain4JDemo() throws SQLException{
        // Constructor
        this.connection = (IRISConnection) DriverManager.getConnection("jdbc:IRIS://localhost:51777/PETPROJECT", "_SYSTEM", "SYS");
    }

    interface Chat {
        @SystemMessage("This is a crude demo, so answer in a crude robotic style.")
        String chat(String userMessage);
    }

    public void chat() {

        IRISChatModel model = IRISChatModel.builder()
            .modelName("AI.LLM.openai")
            .connection(this.connection)
            .build();

        // use directly
        String response = model.chat("What is the capital of France?");
        System.out.println(response);

        // Use with LangChain4J features (AiServices, memory, tools)
        Chat chatbot = AiServices.builder(Chat.class).chatModel(model).build();
        response = chatbot.chat("What is the capital of France?");
        System.out.println(response);
    }
}