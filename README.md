# TradeLens

TradeLens is a SwiftUI-based iOS app designed to help users better understand stock market behavior through real-time market data, portfolio tracking, and AI-assisted trade analysis. The app focuses on education, clarity, and insight rather than direct trading.

This project is actively under development.

---

## Features

- Live market quotes and movers
- Individual stock detail views with price action
- Portfolio overview with performance visuals
- AI-powered trade grading and feedback
- Modular SwiftUI architecture using MVVM

---

## Tech Stack

- Swift 5
- SwiftUI
- MVVM architecture
- iOS 17+
- Finnhub API (market data)
- Anthropic API (AI trade grading)

---

## Project Structure

TradeLens/
├── Models/
├── Views/
├── ViewModels/
├── Services/
│   ├── MarketDataService
│   ├── AIGradingService
├── TradeLensApp.swift
├── Secrets.example.swift

API keys are intentionally excluded from version control.

---

## Setup Instructions

To run this app locally, you will need your own API keys.

### 1. Clone the repository

git clone https://github.com/zl714/TradeLens.git
cd TradeLens

### 2. Add your API keys

1. Open Secrets.example.swift
2. Make a copy of it named Secrets.swift
3. Paste your own API keys into Secrets.swift

Example:

enum Secrets {
    static let finnhubAPIKey = "YOUR_FINNHUB_KEY"
    static let anthropicAPIKey = "YOUR_ANTHROPIC_KEY"
}

Secrets.swift is ignored by Git and will never be committed.

---

### 3. Open in Xcode

- Open TradeLens.xcodeproj
- Select an iOS Simulator or device
- Build and run

---

## API Notes

- Finnhub free tiers may return limited data or 403 errors for certain endpoints
- Candle data access depends on your Finnhub subscription level
- AI grading requests require a valid Anthropic API key

---

## Roadmap

- Improve portfolio analytics
- Add caching and offline handling
- Expand AI trade feedback explanations
- UI polish and performance tuning
- Unit test coverage for services and view models

---

## Disclaimer

TradeLens is for educational purposes only and does not provide financial advice. Market data may be delayed or incomplete depending on API limitations.

---

## Author

Zack LeCroy  
Computer Science Student  
SwiftUI • Systems Design • Data-Driven Apps
