# Queries run

## 2026-07-28 — M4 actuator route (brief §6 blocking decision): Dynamixel current mode vs BLDC+FOC vs SEA, + effort-sensing sub-question

- "Dynamixel current control mode impedance control backdrivable exoskeleton closed issue" — no closed-issue hits, useful EduExo Pro friction-compensation context
- "SimpleFOC gimbal motor impedance control ESP32 torque loop rate github issues" — found issue #338, community torque-control thread
- "series elastic actuator open source hand exoskeleton github tendon driven" — found OpenSEA (paper), Hybrid-Exoskeleton-Glove
- "ODrive backdrivable impedance control low torque cogging stiction github issue" — found anticogging issue #221, discourse threads
- "OpenSEA 3D printed planetary gear series elastic actuator github repository" — no direct repo URL in this pass
- "newdexterity Hybrid-Exoskeleton-Glove github closed issues" — repo located, 0 open issue detail surfaced
- "Dynamixel goal_current torque accuracy low current deadband github issue" — found DynamixelSDK #523, #389, #454, #182(via dynamixel-workbench), #528, #334, #351, #573, #558
- "moteus qdd impedance control loop rate backdrivable github" — bandwidth/architecture background only, no new failure_yield
- WebFetch DynamixelSDK#523 and #454 directly — mined for root cause/resolution
- "inline tendon load cell effort sensing exoskeleton open source github" — OpenExo, EULR force-sensor paper, no dedicated load-cell repo found
- "EMG based patient effort assist-as-needed exoskeleton open source github sensor" — mostly papers, no new open-source repo beyond what's already catalogued
- "Dephy FlexSEA open source series elastic actuator github controller" — found DephyInc/Actuator-Package, ITregear/SeriesElasticActuation-FYP
- WebFetch community.simplefoc.com/t/problems-with-torque-control/6904 — mined lockup/isolation root cause
- ""switched from" Dynamixel OR ODrive OR moteus exoskeleton actuator hand rehabilitation forum" — no dead-end switch narrative surfaced
- "OpenSEA elbow exoskeleton github.com Jenks Levan Stefanovic" — no direct repo link
- WebFetch DynamixelSDK dynamixel-workbench#182 — mined overtorque root cause
- WebFetch frontiersin.org OpenSEA article — found repo URL COMANDLab/SEA_Exoskeleton + motor/encoder/torque specs
- WebFetch github.com/DephyInc/Actuator-Package, github.com/ITregear/SeriesElasticActuation-FYP, github.com/COMANDLab/SEA_Exoskeleton, github.com/newdexterity/Hybrid-Exoskeleton-Glove — license/liveness/hardware checks

Result: 5 new library entries (M4), 6 new failure_yield findings pushed into fyp-troubleshoot SKILL.md §Seam 11. No new repos for M1/M2/M3/M5 this run (out of scope).
