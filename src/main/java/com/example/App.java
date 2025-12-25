package com.example;

public class App {
    public static void main(String[] args) {
        System.out.println("========================================");
        System.out.println("🚀 Hello Uday! Your Docker App is Live!");
        System.out.println("========================================");
        
        // App ko turant band hone se rokne ke liye loop (Server jaisa behave karega)
        try {
            while (true) {
                Thread.sleep(1000);
            }
        } catch (InterruptedException e) {
            e.printStackTrace();
        }
    }
}
