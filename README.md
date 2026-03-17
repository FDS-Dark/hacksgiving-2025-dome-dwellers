[![Review Assignment Due Date](https://classroom.github.com/assets/deadline-readme-button-22041afd0340ce965d47ae6ef1cefeee28c7c493a6346c4f15d667ab976d596c.svg)](https://classroom.github.com/a/RyjKsRDC)
# HacksGiving 2025
Thank you for participating in the HacksGiving 2025 competition!
In collaboriation with MSOE and the Milwaukee Domes Alliance, AI-Club is hoping to provide an opportunity for our talented students to gain more hands-on AI experience for the chance to compete in a $6000, 3-day hackathon -- as well as build solutions that ultimately help a non-profit organization that traditionally is unable to invest into AI solutions!

For more information about what an appropriate solution looks like, as well as important dates, please refer to the [Hacksgiving 2025 Hackathon Rubric](https://msoe365.sharepoint.com/:w:/s/MSOEAI/EWieBmmsRr9BuM91iywVTTIBMr5M9ipwXy8F2m_zf7GDag?e=TL2ATX)


# Project Overview

## Brainstorming Agent

An AI-powered brainstorming assistant to help staff and volunteers at the Milwaukee Domes generate innovative ideas for events, exhibits, and educational programs. The system first distills information from the internet about target botanical gardens in the US, then uses this knowledge to create tailored suggestions based on user input. This tool aims to enhance creativity and support the Domes' mission of promoting environmental education and conservation.

```
                          query
    |----------------| ----------> |---------------------|
    |      User      |             | Brainstorming Agent |
    |----------------| <---------- |---------------------|
            |            response             ^
            |                                 | context
            |   Possible Human                |
            |   Updates            |---------------------|
             --------------------> | Distilled Knowledge |
                                   |---------------------|
                                              ^
                                              | data
                                              |
                                  |----------------------|
                                  | Internet Information |
                                  |----------------------|

 
```