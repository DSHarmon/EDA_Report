-- 声明使用的库
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- 实体定义
entity clock_control is
    generic (
        DEBOUNCE_CNT : integer := 499999;  -- 5ms消抖计数（50MHz时钟：50e6 * 0.010 = 250000，减1为249999）
        SEC_MAX      : integer := 59;
        MIN_MAX      : integer := 59;
        HOUR_MAX     : integer := 23
    );
    port (
        sys_clk      : in  std_logic;                     -- 系统时钟，50MHz
        sys_rst_n    : in  std_logic;                     -- 复位信号，低电平有效
        btn_pause    : in  std_logic;                     -- 暂停/继续按钮
        btn_hour_add : in  std_logic;                     -- 小时+1按钮
        btn_min_add  : in  std_logic;                     -- 分钟+1按钮
        btn_sec_add  : in  std_logic;                     -- 秒+1按钮
        
        -- 控制信号输出
        pause_flag   : out std_logic;                     -- 暂停标志（1=暂停，0=运行）
        hour_in      : in  unsigned(4 downto 0);          -- 当前小时值（从data_gen输入）
        minute_in    : in  unsigned(5 downto 0);          -- 当前分钟值（从data_gen输入）
        second_in    : in  unsigned(5 downto 0);          -- 当前秒值（从data_gen输入）
        hour_out     : out unsigned(4 downto 0);          -- 调整后的小时值（输出到data_gen）
        minute_out   : out unsigned(5 downto 0);          -- 调整后的分钟值（输出到data_gen）
        second_out   : out unsigned(5 downto 0)           -- 调整后的秒值（输出到data_gen）
    );
end entity clock_control;

-- 结构体定义
architecture Behavioral of clock_control is
    -- 按钮消抖相关信号
    signal btn_pause_debounced    : std_logic;
    signal btn_hour_add_debounced : std_logic;
    signal btn_min_add_debounced  : std_logic;
    signal btn_sec_add_debounced  : std_logic;
    
    signal btn_pause_d0           : std_logic;
    signal btn_hour_add_d0        : std_logic;
    signal btn_min_add_d0         : std_logic;
    signal btn_sec_add_d0         : std_logic;
    
    signal btn_pause_edge         : std_logic;
    signal btn_hour_add_edge      : std_logic;
    signal btn_min_add_edge       : std_logic;
    signal btn_sec_add_edge       : std_logic;
    
    -- 消抖计数器
    signal debounce_cnt_pause     : unsigned(18 downto 0);
    signal debounce_cnt_hour      : unsigned(18 downto 0);
    signal debounce_cnt_min       : unsigned(18 downto 0);
    signal debounce_cnt_sec       : unsigned(18 downto 0);
    
    -- 内部状态信号
    signal pause_flag_reg         : std_logic := '0';  -- 默认不暂停
    signal hour_reg               : unsigned(4 downto 0);
    signal minute_reg             : unsigned(5 downto 0);
    signal second_reg             : unsigned(5 downto 0);
    
    -- 按钮同步寄存器（用于输入同步，避免亚稳态）
    signal btn_pause_sync         : std_logic_vector(1 downto 0) := (others => '1');
    signal btn_hour_add_sync      : std_logic_vector(1 downto 0) := (others => '1');
    signal btn_min_add_sync       : std_logic_vector(1 downto 0) := (others => '1');
    signal btn_sec_add_sync       : std_logic_vector(1 downto 0) := (others => '1');
    
    -- 中间寄存器，用于稳定更新，避免竞争条件
    signal hour_next              : unsigned(4 downto 0);
    signal minute_next            : unsigned(5 downto 0);
    signal second_next            : unsigned(5 downto 0);
    signal update_flag            : std_logic := '0';
    
    -- 按键锁定信号，防止抖动期间的多次触发
    signal btn_hour_locked        : std_logic := '0';
    signal btn_min_locked         : std_logic := '0';
    signal btn_sec_locked         : std_logic := '0';
    
    -- 锁定计数器
    constant LOCK_DELAY           : integer := 999999;  -- 20ms 按键锁定延迟
    signal hour_lock_cnt          : integer range 0 to LOCK_DELAY := 0;
    signal min_lock_cnt           : integer range 0 to LOCK_DELAY := 0;
    signal sec_lock_cnt           : integer range 0 to LOCK_DELAY := 0;
    
begin
    -- 按钮消抖处理 - 优化版本，使用更可靠的消抖机制
    -- 分离同步、消抖和边沿检测逻辑，确保每个阶段独立工作
    
    -- 1. 输入同步（避免亚稳态）
    process(sys_clk, sys_rst_n)
    begin
        if sys_rst_n = '0' then
            -- 复位所有同步寄存器
            btn_pause_sync    <= (others => '1');  -- 默认高电平（未按下）
            btn_hour_add_sync <= (others => '1');
            btn_min_add_sync  <= (others => '1');
            btn_sec_add_sync  <= (others => '1');
        elsif rising_edge(sys_clk) then
            -- 两级同步输入信号，避免亚稳态
            btn_pause_sync    <= btn_pause_sync(0) & btn_pause;
            btn_hour_add_sync <= btn_hour_add_sync(0) & btn_hour_add;
            btn_min_add_sync  <= btn_min_add_sync(0) & btn_min_add;
            btn_sec_add_sync  <= btn_sec_add_sync(0) & btn_sec_add;
        end if;
    end process;
    
    -- 2. 按键消抖逻辑（分离的进程）
    process(sys_clk, sys_rst_n)
    begin
        if sys_rst_n = '0' then
            -- 复位所有消抖计数器和消抖后的信号
            debounce_cnt_pause     <= (others => '0');
            debounce_cnt_hour      <= (others => '0');
            debounce_cnt_min       <= (others => '0');
            debounce_cnt_sec       <= (others => '0');
            btn_pause_debounced    <= '1';  -- 默认高电平（未按下）
            btn_hour_add_debounced <= '1';
            btn_min_add_debounced  <= '1';
            btn_sec_add_debounced  <= '1';
        elsif rising_edge(sys_clk) then
            -- 暂停/继续按钮消抖（按键按下为低电平）
            if btn_pause_sync(1) = '0' then  -- 按键按下
                if debounce_cnt_pause < DEBOUNCE_CNT then
                    debounce_cnt_pause <= debounce_cnt_pause + 1;
                else
                    btn_pause_debounced <= '0';  -- 消抖后输出低电平表示按下
                    debounce_cnt_pause <= to_unsigned(DEBOUNCE_CNT, debounce_cnt_pause'length);  -- 保持最大值
                end if;
            else  -- 按键释放
                if debounce_cnt_pause > 0 then
                    debounce_cnt_pause <= debounce_cnt_pause - 1;
                else
                    btn_pause_debounced <= '1';  -- 消抖后输出高电平表示释放
                end if;
            end if;
            
            -- 小时+1按钮消抖
            if btn_hour_add_sync(1) = '0' then  -- 按键按下
                if debounce_cnt_hour < DEBOUNCE_CNT then
                    debounce_cnt_hour <= debounce_cnt_hour + 1;
                else
                    btn_hour_add_debounced <= '0';  -- 消抖后输出低电平表示按下
                    debounce_cnt_hour <= to_unsigned(DEBOUNCE_CNT, debounce_cnt_hour'length);  -- 保持最大值
                end if;
            else  -- 按键释放
                if debounce_cnt_hour > 0 then
                    debounce_cnt_hour <= debounce_cnt_hour - 1;
                else
                    btn_hour_add_debounced <= '1';  -- 消抖后输出高电平表示释放
                end if;
            end if;
            
            -- 分钟+1按钮消抖
            if btn_min_add_sync(1) = '0' then  -- 按键按下
                if debounce_cnt_min < DEBOUNCE_CNT then
                    debounce_cnt_min <= debounce_cnt_min + 1;
                else
                    btn_min_add_debounced <= '0';  -- 消抖后输出低电平表示按下
                    debounce_cnt_min <= to_unsigned(DEBOUNCE_CNT, debounce_cnt_min'length);  -- 保持最大值
                end if;
            else  -- 按键释放
                if debounce_cnt_min > 0 then
                    debounce_cnt_min <= debounce_cnt_min - 1;
                else
                    btn_min_add_debounced <= '1';  -- 消抖后输出高电平表示释放
                end if;
            end if;
            
            -- 秒+1按钮消抖
            if btn_sec_add_sync(1) = '0' then  -- 按键按下
                if debounce_cnt_sec < DEBOUNCE_CNT then
                    debounce_cnt_sec <= debounce_cnt_sec + 1;
                else
                    btn_sec_add_debounced <= '0';  -- 消抖后输出低电平表示按下
                    debounce_cnt_sec <= to_unsigned(DEBOUNCE_CNT, debounce_cnt_sec'length);  -- 保持最大值
                end if;
            else  -- 按键释放
                if debounce_cnt_sec > 0 then
                    debounce_cnt_sec <= debounce_cnt_sec - 1;
                else
                    btn_sec_add_debounced <= '1';  -- 消抖后输出高电平表示释放
                end if;
            end if;
        end if;
    end process;
    
    -- 3. 保存上一个状态，用于边缘检测
    process(sys_clk, sys_rst_n)
    begin
        if sys_rst_n = '0' then
            btn_pause_d0           <= '1';
            btn_hour_add_d0        <= '1';
            btn_min_add_d0         <= '1';
            btn_sec_add_d0         <= '1';
        elsif rising_edge(sys_clk) then
            btn_pause_d0 <= btn_pause_debounced;
            btn_hour_add_d0 <= btn_hour_add_debounced;
            btn_min_add_d0 <= btn_min_add_debounced;
            btn_sec_add_d0 <= btn_sec_add_debounced;
        end if;
    end process;
    
    -- 4. 检测按钮下降沿（按键按下时产生一个时钟周期的触发信号）
    -- 因为实际按键输入是按下为低电平，所以检测的是从高到低的变化
    process(sys_clk, sys_rst_n)
    begin
        if sys_rst_n = '0' then
            btn_pause_edge <= '0';
        elsif rising_edge(sys_clk) then
            -- 暂停按钮边沿检测
            if (btn_pause_d0 = '1' and btn_pause_debounced = '0') then
                btn_pause_edge <= '1';
            else
                btn_pause_edge <= '0';
            end if;
        end if;
    end process;
    
    -- 5. 为时间调整按钮添加边沿检测和锁定机制
    -- 使用更严格的锁定逻辑，确保每个按键按下只触发一次
    process(sys_clk, sys_rst_n)
    begin
        if sys_rst_n = '0' then
            btn_hour_add_edge <= '0';
            btn_min_add_edge <= '0';
            btn_sec_add_edge <= '0';
            btn_hour_locked <= '0';
            btn_min_locked <= '0';
            btn_sec_locked <= '0';
            hour_lock_cnt <= 0;
            min_lock_cnt <= 0;
            sec_lock_cnt <= 0;
        elsif rising_edge(sys_clk) then
            -- 默认情况下，清除所有边沿信号
            btn_hour_add_edge <= '0';
            btn_min_add_edge <= '0';
            btn_sec_add_edge <= '0';
            
            -- 小时按钮处理
            if btn_hour_locked = '0' then
                -- 检测到下降沿（按键按下）
                if (btn_hour_add_d0 = '1' and btn_hour_add_debounced = '0') then
                    btn_hour_add_edge <= '1';  -- 产生一个时钟周期的触发信号
                    btn_hour_locked <= '1';    -- 锁定按钮
                    hour_lock_cnt <= LOCK_DELAY;  -- 设置锁定延迟
                end if;
            else
                -- 锁定期间，递减计数器
                if hour_lock_cnt > 0 then
                    hour_lock_cnt <= hour_lock_cnt - 1;
                else
                    -- 锁定延迟结束，检查按钮是否已经释放
                    if btn_hour_add_debounced = '1' then
                        btn_hour_locked <= '0';  -- 解锁按钮
                    end if;
                end if;
            end if;
            
            -- 分钟按钮处理
            if btn_min_locked = '0' then
                -- 检测到下降沿（按键按下）
                if (btn_min_add_d0 = '1' and btn_min_add_debounced = '0') then
                    btn_min_add_edge <= '1';  -- 产生一个时钟周期的触发信号
                    btn_min_locked <= '1';    -- 锁定按钮
                    min_lock_cnt <= LOCK_DELAY;  -- 设置锁定延迟
                end if;
            else
                -- 锁定期间，递减计数器
                if min_lock_cnt > 0 then
                    min_lock_cnt <= min_lock_cnt - 1;
                else
                    -- 锁定延迟结束，检查按钮是否已经释放
                    if btn_min_add_debounced = '1' then
                        btn_min_locked <= '0';  -- 解锁按钮
                    end if;
                end if;
            end if;
            
            -- 秒按钮处理
            if btn_sec_locked = '0' then
                -- 检测到下降沿（按键按下）
                if (btn_sec_add_d0 = '1' and btn_sec_add_debounced = '0') then
                    btn_sec_add_edge <= '1';  -- 产生一个时钟周期的触发信号
                    btn_sec_locked <= '1';    -- 锁定按钮
                    sec_lock_cnt <= LOCK_DELAY;  -- 设置锁定延迟
                end if;
            else
                -- 锁定期间，递减计数器
                if sec_lock_cnt > 0 then
                    sec_lock_cnt <= sec_lock_cnt - 1;
                else
                    -- 锁定延迟结束，检查按钮是否已经释放
                    if btn_sec_add_debounced = '1' then
                        btn_sec_locked <= '0';  -- 解锁按钮
                    end if;
                end if;
            end if;
        end if;
    end process;
    
    -- 暂停/继续控制逻辑
    process(sys_clk, sys_rst_n)
    begin
        if sys_rst_n = '0' then
            pause_flag_reg <= '0';  -- 复位时不暂停
        elsif rising_edge(sys_clk) then
            -- 切换暂停状态
            if btn_pause_edge = '1' then
                pause_flag_reg <= not pause_flag_reg;  -- 切换暂停状态
            end if;
        end if;
    end process;
    
    -- 时间调整逻辑 - 优化版，简化流程，确保每个按键按下只更新一次
    process(sys_clk, sys_rst_n)
    begin
        if sys_rst_n = '0' then
            hour_reg   <= (others => '0');
            minute_reg <= (others => '0');
            second_reg <= (others => '0');
        elsif rising_edge(sys_clk) then
            if pause_flag_reg = '1' then
                -- 暂停状态：直接在检测到有效边沿信号时更新
                -- 使用顺序执行，确保一次只处理一个按键
                if btn_hour_add_edge = '1' then
                    -- 小时增加
                    if hour_reg = HOUR_MAX then
                        hour_reg <= (others => '0');
                    else
                        hour_reg <= hour_reg + 1;
                    end if;
                elsif btn_min_add_edge = '1' then
                    -- 分钟增加
                    if minute_reg = MIN_MAX then
                        minute_reg <= (others => '0');
                    else
                        minute_reg <= minute_reg + 1;
                    end if;
                elsif btn_sec_add_edge = '1' then
                    -- 秒增加
                    if second_reg = SEC_MAX then
                        second_reg <= (others => '0');
                    else
                        second_reg <= second_reg + 1;
                    end if;
                end if;
            else
                -- 运行状态：直接同步当前时间值
                hour_reg   <= hour_in;
                minute_reg <= minute_in;
                second_reg <= second_in;
            end if;
        end if;
    end process;
    
    -- 输出赋值
    pause_flag <= pause_flag_reg;
    hour_out   <= hour_reg;
    minute_out <= minute_reg;
    second_out <= second_reg;
    
end architecture Behavioral;