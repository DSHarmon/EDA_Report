-- 交通灯控制模块
-- 实现三种模式的交通灯状态机和倒计时功能
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity traffic_light_ctrl is
    port (
        sys_clk          : in  std_logic;
        sys_rst_n        : in  std_logic;
        state_change     : in  std_logic;                    -- 模式/状态切换信号（下降沿触发）
        
        -- 交通灯输出
        main_red         : out std_logic;
        main_yellow      : out std_logic;
        main_green       : out std_logic;
        branch_red       : out std_logic;
        branch_yellow    : out std_logic;
        branch_green     : out std_logic;
        
        -- 倒计时输出
        main_countdown   : out unsigned(5 downto 0);        -- 主干道倒计时（秒）
        branch_countdown : out unsigned(5 downto 0)         -- 支干道倒计时（秒）
    );
end entity traffic_light_ctrl;

architecture Behavioral of traffic_light_ctrl is
    -- 交通灯状态定义
    type traffic_state is (
        S_MAIN_GREEN_BRANCH_RED,   -- 主干道绿，支干道红
        S_MAIN_YELLOW_BRANCH_RED,  -- 主干道黄，支干道红
        S_MAIN_RED_BRANCH_GREEN,   -- 主干道红，支干道绿
        S_MAIN_RED_BRANCH_YELLOW   -- 主干道红，支干道黄
    );
    
    -- 模式定义
    type mode_type is (
        MODE_1,  -- 模式1：主干道常绿，支干道常红
        MODE_2,  -- 模式2：各状态5秒循环
        MODE_3   -- 模式3：不同时间循环
    );
    
    -- 模式1：无倒计时，固定状态
    -- 模式2：各状态5秒
    constant MODE2_MAIN_GREEN_TIME  : integer := 5;
    constant MODE2_MAIN_YELLOW_TIME : integer := 5;
    constant MODE2_BRANCH_GREEN_TIME: integer := 5;
    constant MODE2_BRANCH_YELLOW_TIME: integer := 5;
    
    -- 模式3：不同时间
    constant MODE3_MAIN_GREEN_TIME  : integer := 45;
    constant MODE3_MAIN_YELLOW_TIME : integer := 5;
    constant MODE3_BRANCH_GREEN_TIME: integer := 25;
    constant MODE3_BRANCH_YELLOW_TIME: integer := 5;
    
    -- 时钟计数器信号
    signal cnt_1sec  : unsigned(25 downto 0) := (others => '0');  -- 1秒计数器
    signal flag_1sec : std_logic := '0';                          -- 1秒脉冲标志
    
    -- 模式信号
    signal current_mode : mode_type := MODE_1;  -- 当前模式，默认为模式1
    
    -- 交通灯状态信号
    signal current_state : traffic_state := S_MAIN_GREEN_BRANCH_RED;
    signal next_state    : traffic_state;
    
    -- 时间参数信号
    signal main_green_time  : integer;
    signal main_yellow_time : integer;
    signal branch_green_time: integer;
    signal branch_yellow_time: integer;
    
    -- 倒计时信号
    signal countdown_main : unsigned(5 downto 0) := (others => '0');
    signal countdown_branch : unsigned(5 downto 0) := (others => '0');
    
    -- 交通灯输出信号
    signal main_red_reg    : std_logic := '0';
    signal main_yellow_reg : std_logic := '0';
    signal main_green_reg  : std_logic := '1';
    signal branch_red_reg  : std_logic := '1';
    signal branch_yellow_reg: std_logic := '0';
    signal branch_green_reg: std_logic := '0';
    
    -- 状态切换标志
    signal state_change_flag : std_logic := '0';
    
begin
    -- 1. 1秒计数器
    process(sys_clk, sys_rst_n)
    begin
        if sys_rst_n = '0' then
            cnt_1sec <= (others => '0');
        elsif rising_edge(sys_clk) then
            if cnt_1sec = to_unsigned(49999999, 26) then -- 50MHz时钟，1秒计数
                cnt_1sec <= (others => '0');
            else
                cnt_1sec <= cnt_1sec + 1;
            end if;
        end if;
    end process;
    
    -- 2. 1秒脉冲标志
    process(sys_clk, sys_rst_n)
    begin
        if sys_rst_n = '0' then
            flag_1sec <= '0';
        elsif rising_edge(sys_clk) then
            if cnt_1sec = to_unsigned(49999998, 26) then
                flag_1sec <= '1';
            else
                flag_1sec <= '0';
            end if;
        end if;
    end process;
    
    -- 3. 模式切换逻辑
    process(sys_clk, sys_rst_n)
    begin
        if sys_rst_n = '0' then
            current_mode <= MODE_1;
        elsif rising_edge(sys_clk) then
            if state_change = '1' then
                -- 按钮按下，切换到下一个模式
                case current_mode is
                    when MODE_1 =>
                        current_mode <= MODE_2;
                    when MODE_2 =>
                        current_mode <= MODE_3;
                    when MODE_3 =>
                        current_mode <= MODE_1;
                end case;
            end if;
        end if;
    end process;
    
    -- 4. 时间参数选择逻辑
    process(current_mode)
    begin
        case current_mode is
            when MODE_1 =>
                -- 模式1：无倒计时，使用默认时间但不实际倒计时
                main_green_time <= 0;
                main_yellow_time <= 0;
                branch_green_time <= 0;
                branch_yellow_time <= 0;
                
            when MODE_2 =>
                -- 模式2：各状态5秒
                main_green_time <= MODE2_MAIN_GREEN_TIME;
                main_yellow_time <= MODE2_MAIN_YELLOW_TIME;
                branch_green_time <= MODE2_BRANCH_GREEN_TIME;
                branch_yellow_time <= MODE2_BRANCH_YELLOW_TIME;
                
            when MODE_3 =>
                -- 模式3：不同时间
                main_green_time <= MODE3_MAIN_GREEN_TIME;
                main_yellow_time <= MODE3_MAIN_YELLOW_TIME;
                branch_green_time <= MODE3_BRANCH_GREEN_TIME;
                branch_yellow_time <= MODE3_BRANCH_YELLOW_TIME;
        end case;
    end process;
    
    -- 5. 状态转换逻辑
    process(sys_clk, sys_rst_n)
    begin
        if sys_rst_n = '0' then
            current_state <= S_MAIN_GREEN_BRANCH_RED;
        elsif rising_edge(sys_clk) then
            if state_change = '1' then
                -- 模式切换时，重置到初始状态
                current_state <= S_MAIN_GREEN_BRANCH_RED;
            elsif current_mode = MODE_1 then
                -- 模式1：固定状态，不切换
                current_state <= S_MAIN_GREEN_BRANCH_RED;
            else
                -- 模式2和3：根据倒计时或按钮切换状态
                if state_change_flag = '1' or (flag_1sec = '1' and (countdown_main = 1 or countdown_branch = 1)) then
                    current_state <= next_state;
                end if;
            end if;
        end if;
    end process;
    
    -- 4. 下一状态确定
    process(current_state)
    begin
        case current_state is
            when S_MAIN_GREEN_BRANCH_RED =>
                next_state <= S_MAIN_YELLOW_BRANCH_RED;
            when S_MAIN_YELLOW_BRANCH_RED =>
                next_state <= S_MAIN_RED_BRANCH_GREEN;
            when S_MAIN_RED_BRANCH_GREEN =>
                next_state <= S_MAIN_RED_BRANCH_YELLOW;
            when S_MAIN_RED_BRANCH_YELLOW =>
                next_state <= S_MAIN_GREEN_BRANCH_RED;
        end case;
    end process;
    
    -- 6. 状态切换标志处理
    process(sys_clk, sys_rst_n)
    begin
        if sys_rst_n = '0' then
            state_change_flag <= '0';
        elsif rising_edge(sys_clk) then
            if state_change = '1' and current_mode /= MODE_1 then
                -- 非模式1下，按钮按下触发状态切换
                state_change_flag <= '1';
            else
                state_change_flag <= '0';
            end if;
        end if;
    end process;
    
    -- 7. 倒计时逻辑
    process(sys_clk, sys_rst_n)
    begin
        if sys_rst_n = '0' then
            countdown_main <= (others => '0');
            countdown_branch <= (others => '0');
        elsif rising_edge(sys_clk) then
            case current_mode is
                when MODE_1 =>
                    -- 模式1：常绿常红，无倒计时
                    countdown_main <= (others => '0');
                    countdown_branch <= (others => '0');
                    
                when others =>
                    -- 模式2和3：有倒计时
                    if state_change_flag = '1' then
                        -- 手动切换状态时，重置倒计时
                        case next_state is
                            when S_MAIN_GREEN_BRANCH_RED =>
                                countdown_main <= to_unsigned(main_green_time, 6);
                                countdown_branch <= (others => '0');
                            when S_MAIN_YELLOW_BRANCH_RED =>
                                countdown_main <= to_unsigned(main_yellow_time, 6);
                                countdown_branch <= (others => '0');
                            when S_MAIN_RED_BRANCH_GREEN =>
                                countdown_main <= (others => '0');
                                countdown_branch <= to_unsigned(branch_green_time, 6);
                            when S_MAIN_RED_BRANCH_YELLOW =>
                                countdown_main <= (others => '0');
                                countdown_branch <= to_unsigned(branch_yellow_time, 6);
                        end case;
                    elsif flag_1sec = '1' then
                        if countdown_main > 1 then
                            countdown_main <= countdown_main - 1;
                        elsif countdown_branch > 1 then
                            countdown_branch <= countdown_branch - 1;
                        elsif countdown_main = 1 or countdown_branch = 1 then
                            -- 状态切换时重置倒计时
                            case next_state is
                                when S_MAIN_GREEN_BRANCH_RED =>
                                    countdown_main <= to_unsigned(main_green_time, 6);
                                    countdown_branch <= (others => '0');
                                when S_MAIN_YELLOW_BRANCH_RED =>
                                    countdown_main <= to_unsigned(main_yellow_time, 6);
                                    countdown_branch <= (others => '0');
                                when S_MAIN_RED_BRANCH_GREEN =>
                                    countdown_main <= (others => '0');
                                    countdown_branch <= to_unsigned(branch_green_time, 6);
                                when S_MAIN_RED_BRANCH_YELLOW =>
                                    countdown_main <= (others => '0');
                                    countdown_branch <= to_unsigned(branch_yellow_time, 6);
                            end case;
                        end if;
                    end if;
            end case;
        end if;
    end process;
    
    -- 6. 交通灯输出逻辑
    process(sys_clk, sys_rst_n)
    begin
        if sys_rst_n = '0' then
            main_red_reg    <= '0';
            main_yellow_reg <= '0';
            main_green_reg  <= '1';
            branch_red_reg  <= '1';
            branch_yellow_reg <= '0';
            branch_green_reg <= '0';
        elsif rising_edge(sys_clk) then
            case current_state is
                when S_MAIN_GREEN_BRANCH_RED =>
                    main_red_reg    <= '0';
                    main_yellow_reg <= '0';
                    main_green_reg  <= '1';
                    branch_red_reg  <= '1';
                    branch_yellow_reg <= '0';
                    branch_green_reg <= '0';
                    
                when S_MAIN_YELLOW_BRANCH_RED =>
                    main_red_reg    <= '0';
                    main_yellow_reg <= '1';
                    main_green_reg  <= '0';
                    branch_red_reg  <= '1';
                    branch_yellow_reg <= '0';
                    branch_green_reg <= '0';
                    
                when S_MAIN_RED_BRANCH_GREEN =>
                    main_red_reg    <= '1';
                    main_yellow_reg <= '0';
                    main_green_reg  <= '0';
                    branch_red_reg  <= '0';
                    branch_yellow_reg <= '0';
                    branch_green_reg <= '1';
                    
                when S_MAIN_RED_BRANCH_YELLOW =>
                    main_red_reg    <= '1';
                    main_yellow_reg <= '0';
                    main_green_reg  <= '0';
                    branch_red_reg  <= '0';
                    branch_yellow_reg <= '1';
                    branch_green_reg <= '0';
            end case;
        end if;
    end process;
    
    -- 输出赋值
    main_red         <= main_red_reg;
    main_yellow      <= main_yellow_reg;
    main_green       <= main_green_reg;
    branch_red       <= branch_red_reg;
    branch_yellow    <= branch_yellow_reg;
    branch_green     <= branch_green_reg;
    main_countdown   <= countdown_main;
    branch_countdown <= countdown_branch;
    
end architecture Behavioral;