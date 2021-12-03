#See https://aka.ms/containerfastmode to understand how Visual Studio uses this Dockerfile to build your images for faster debugging.

FROM mcr.microsoft.com/dotnet/runtime:6.0 AS base
WORKDIR /app

FROM mcr.microsoft.com/dotnet/sdk:6.0 AS build
WORKDIR /src
COPY ["Distributed.IoT.Edge.SimulatedTemperatureSensorModule/Distributed.IoT.Edge.SimulatedTemperatureSensorModule.csproj", "Distributed.IoT.Edge.SimulatedTemperatureSensorModule/"]
RUN dotnet restore "Distributed.IoT.Edge.SimulatedTemperatureSensorModule/Distributed.IoT.Edge.SimulatedTemperatureSensorModule.csproj"
COPY . .
WORKDIR "/src/Distributed.IoT.Edge.SimulatedTemperatureSensorModule"
RUN dotnet build "Distributed.IoT.Edge.SimulatedTemperatureSensorModule.csproj" -c Release -o /app/build

FROM build AS publish
RUN dotnet publish "Distributed.IoT.Edge.SimulatedTemperatureSensorModule.csproj" -c Release -o /app/publish

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "Distributed.IoT.Edge.SimulatedTemperatureSensorModule.dll"]