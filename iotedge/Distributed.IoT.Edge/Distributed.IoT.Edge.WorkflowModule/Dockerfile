FROM mcr.microsoft.com/dotnet/aspnet:6.0 AS base
WORKDIR /app
EXPOSE 80
EXPOSE 443

FROM mcr.microsoft.com/dotnet/sdk:6.0 AS build
WORKDIR /src
COPY ["Distributed.IoT.Edge.WorkflowModule/Distributed.IoT.Edge.WorkflowModule.csproj", "Distributed.IoT.Edge.WorkflowModule/"]
RUN dotnet restore "Distributed.IoT.Edge.WorkflowModule/Distributed.IoT.Edge.WorkflowModule.csproj"
COPY . .
WORKDIR "/src/Distributed.IoT.Edge.WorkflowModule"
RUN dotnet build "Distributed.IoT.Edge.WorkflowModule.csproj" -c Release -o /app/build

FROM build AS publish
RUN dotnet publish "Distributed.IoT.Edge.WorkflowModule.csproj" -c Release -o /app/publish

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "Distributed.IoT.Edge.WorkflowModule.dll"]
