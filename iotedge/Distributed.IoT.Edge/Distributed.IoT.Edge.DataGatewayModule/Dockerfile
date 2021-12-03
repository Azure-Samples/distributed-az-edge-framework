#See https://aka.ms/containerfastmode to understand how Visual Studio uses this Dockerfile to build your images for faster debugging.

FROM mcr.microsoft.com/dotnet/aspnet:6.0 AS base
WORKDIR /app
EXPOSE 80
EXPOSE 443

FROM mcr.microsoft.com/dotnet/sdk:6.0 AS build
WORKDIR /src
COPY ["Distributed.IoT.Edge.DataGatewayModule/Distributed.IoT.Edge.DataGatewayModule.csproj", "Distributed.IoT.Edge.DataGatewayModule/"]
RUN dotnet restore "Distributed.IoT.Edge.DataGatewayModule/Distributed.IoT.Edge.DataGatewayModule.csproj"
COPY . .
WORKDIR "/src/Distributed.IoT.Edge.DataGatewayModule"
RUN dotnet build "Distributed.IoT.Edge.DataGatewayModule.csproj" -c Release -o /app/build

FROM build AS publish
RUN dotnet publish "Distributed.IoT.Edge.DataGatewayModule.csproj" -c Release -o /app/publish

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "Distributed.IoT.Edge.DataGatewayModule.dll"]
