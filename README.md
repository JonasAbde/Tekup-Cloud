# Tekup Cloud - Portfolio Knowledge Base

Central dokumentation, strategisk analyse og audit scripts for hele Tekup Portfolio.

## 📋 Indhold

Dette repository indeholder:

- **Strategisk Analyse** - Portfolio-niveau audit og konsolideringsstrategier
- **AI Assistant Configuration** - ChatGPT custom instructions og knowledge base
- **Audit Scripts** - PowerShell scripts til automatisk portfolio scanning
- **Deployment Status** - Render.com og produktionsmiljø tracking
- **Individual Project Analysis** - Detaljeret analyse af:
  - TekupVault (semantic search + GitHub sync)
  - Tekup-Billy (Billy.dk MCP integration)
  - RendetaljeOS (RenOS backend/frontend)
  - Dashboard projekter

## 🎯 Formål

Tekup-Cloud fungerer som:

1. **Central Knowledge Hub** - Samlet dokumentation på tværs af alle Tekup projekter
2. **AI Assistant Training Data** - Custom instructions og kontekst for ChatGPT/Copilot
3. **Portfolio Auditing** - Scripts til at scanne og analysere hele portfolioen
4. **Strategic Planning** - Konsolideringsstrategier og arkitektur beslutninger

## 🛠 Audit Scripts

### Quick Audit
```powershell
.\audit-simple.ps1
```

### Complete Portfolio Scan
```powershell
.\Tekup-Portfolio-Audit.ps1
```

### Generate Report
```powershell
.\generate-audit-report.ps1
```

## 📁 Struktur

```
Tekup-Cloud/
├── AI_ASSISTANT_*.md          # ChatGPT/Copilot instruktioner
├── PORTFOLIO_*.md             # Portfolio-niveau analyse
├── TEKUP_*_ANALYSIS_*.md      # Individuelle projekt analyser
├── audit-results/             # Genererede audit rapporter
├── scripts/                   # PowerShell automation scripts
└── .qoder/                    # Qoder.com integration
```

## 🔗 Relaterede Projekter

- [TekupVault](https://github.com/JonasAbde/TekupVault) - Semantic search across portfolio
- [Tekup-Billy](https://github.com/JonasAbde/Tekup-Billy) - Billy.dk MCP server
- [RendetaljeOS](https://github.com/JonasAbde/renos-backend) - Backend API
- [RendetaljeOS Frontend](https://github.com/JonasAbde/renos-frontend) - React UI

## 📊 Portfolio Status

Se `PORTFOLIO_EXECUTIVE_SUMMARY.md` for seneste konsolideringsstatus og strategiske beslutninger.

## 🤖 Qoder Integration

Dette repository er forbundet til [Qoder.com](https://qoder.com) for AI-drevet projektledelse og automatisering.

## 📝 Licens

Tekup Portfolio - Internal Documentation

---

**Last Updated:** October 18, 2025
