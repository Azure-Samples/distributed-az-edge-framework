#See https://aka.ms/containerfastmode to understand how Visual Studio uses this Dockerfile to build your images for faster debugging.

FROM mcr.microsoft.com/dotnet/runtime:6.0 AS base
WORKDIR /app

FROM mcr.microsoft.com/dotnet/sdk:6.0 AS build
WORKDIR /src
COPY ["Distributed.Azure.IoT.Edge.SimulatedTemperatureSensorModule/Distributed.Azure.IoT.Edge.SimulatedTemperatureSensorModule.csproj", "Distributed.Azure.IoT.Edge.SimulatedTemperatureSensorModule/"]
RUN dotnet restore "Distributed.Azure.IoT.Edge.SimulatedTemperatureSensorModule/Distributed.Azure.IoT.Edge.SimulatedTemperatureSensorModule.csproj"
COPY . .
WORKDIR "/src/Distributed.Azure.IoT.Edge.SimulatedTemperatureSensorModule"
RUN dotnet build "Distributed.Azure.IoT.Edge.SimulatedTemperatureSensorModule.csproj" -c Release -o /app/build

FROM build AS publish
RUN dotnet publish "Distributed.Azure.IoT.Edge.SimulatedTemperatureSensorModule.csproj" -c Release -o /app/publish

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "Distributed.Azure.IoT.Edge.SimulatedTemperatureSensorModule.dll"]