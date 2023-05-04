FROM mcr.microsoft.com/dotnet/runtime:6.0 AS base
WORKDIR /app

FROM mcr.microsoft.com/dotnet/sdk:6.0 AS build
WORKDIR /src
COPY ["Distributed.IoT.Edge.WorkflowApp/Distributed.IoT.Edge.WorkflowApp.csproj", "Distributed.IoT.Edge.WorkflowApp/"]
RUN dotnet restore "Distributed.IoT.Edge.WorkflowApp/Distributed.IoT.Edge.WorkflowApp.csproj"
COPY . .
WORKDIR "/src/Distributed.IoT.Edge.WorkflowApp"
RUN dotnet build "Distributed.IoT.Edge.WorkflowApp.csproj" -c Release -o /app/build

FROM build AS publish
RUN dotnet publish "Distributed.IoT.Edge.WorkflowApp.csproj" -c Release -o /app/publish /p:UseAppHost=false

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "Distributed.IoT.Edge.WorkflowApp.dll"]
